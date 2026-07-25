import Foundation
import AppKit
import CryptoKit
import MacOptimizationCore

struct UpdateCheckResult {
    let hasNewVersion: Bool
    let latestVersion: String
    let message: String
    let downloadURL: URL?
    /// GitHub Release API 가 제공하는 자산 다이제스트 (`sha256:...`). 없으면 nil.
    let expectedSHA256: String?
}

/// GitHub Release 기반 인앱 업데이터.
///
/// 보안 요구사항:
/// - 다운로드 URL 은 HTTPS + GitHub 배포 호스트로 제한한다.
/// - 릴리스 API 가 제공하는 SHA-256 다이제스트와 실제 파일 해시를 대조한 경우에만 자동 마운트한다.
/// - 다이제스트를 확인할 수 없으면 자동 마운트하지 않고 사용자에게 파일 위치와 해시를 제시한다.
@MainActor
final class SparkleUpdaterManager: NSObject, ObservableObject, URLSessionDownloadDelegate {
    static let shared = SparkleUpdaterManager()

    @Published var isDownloading: Bool = false
    @Published var downloadProgress: Double = 0.0
    @Published var statusMessage: String = ""

    private var downloadTask: URLSessionDownloadTask?
    private var downloadContinuation: CheckedContinuation<URL, Error>?

    private static let releaseAPIURL = URL(string: "https://api.github.com/repos/crazy-vincnet/MacOptimizationTool/releases/latest")!
    private static let releasesPageURL = URL(string: "https://github.com/crazy-vincnet/MacOptimizationTool/releases/latest")!

    private override init() {
        super.init()
    }

    // MARK: - Version helpers

    /// 앱 번들의 현재 버전 문자열.
    private static var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    // MARK: - Update check

    func checkForUpdates(completion: @escaping (UpdateCheckResult) -> Void) {
        var request = URLRequest(url: Self.releaseAPIURL)
        request.timeoutInterval = 10
        request.setValue("MacOptimizationTool/\(Self.currentVersion)", forHTTPHeaderField: "User-Agent")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        Task {
            let current = UpdateVerification.normalizedVersion(Self.currentVersion)

            guard let payload = try? await URLSession.shared.data(for: request),
                  let httpResponse = payload.1 as? HTTPURLResponse, httpResponse.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: payload.0) as? [String: Any],
                  let latestTag = json["tag_name"] as? String else {
                completion(UpdateCheckResult(hasNewVersion: false,
                                             latestVersion: "v\(current)",
                                             message: String(format: t("settings.updateAlert"), current),
                                             downloadURL: Self.releasesPageURL,
                                             expectedSHA256: nil))
                return
            }

            let assets = json["assets"] as? [[String: Any]] ?? []
            var dmgDownloadURL: URL?
            var digest: String?
            for asset in assets {
                guard let name = asset["name"] as? String, name.hasSuffix(".dmg"),
                      let urlString = asset["browser_download_url"] as? String,
                      let url = URL(string: urlString), UpdateVerification.isTrustedDownloadURL(url) else { continue }
                dmgDownloadURL = url
                // GitHub 은 자산 다이제스트를 "sha256:<hex>" 형식으로 제공한다.
                digest = UpdateVerification.parseSHA256Digest(asset["digest"] as? String)
                break
            }

            let cleanTag = UpdateVerification.normalizedVersion(latestTag)
            let displayTag = "v\(cleanTag)"
            let isNewer = UpdateVerification.isNewerVersion(latest: cleanTag, current: current)

            completion(UpdateCheckResult(
                hasNewVersion: isNewer,
                latestVersion: displayTag,
                message: isNewer
                    ? String(format: t("update.newVersionMessage"), displayTag)
                    : String(format: t("settings.updateAlert"), current),
                downloadURL: dmgDownloadURL ?? Self.releasesPageURL,
                expectedSHA256: digest
            ))
        }
    }

    // MARK: - Download & install

    /// 인앱 다운로드 후 무결성 검증에 성공한 경우에만 `.dmg` 를 자동 마운트한다.
    func startDirectDownloadAndInstall(from downloadURL: URL, expectedSHA256: String?) {
        guard UpdateVerification.isTrustedDownloadURL(downloadURL) else {
            self.statusMessage = t("update.status.untrustedURL")
            NSWorkspace.shared.open(Self.releasesPageURL)
            return
        }

        self.isDownloading = true
        self.downloadProgress = 0.01
        self.statusMessage = t("update.status.connecting")

        Task {
            do {
                let downloadedTempURL = try await startDownloadWithProgress(url: downloadURL)
                let destinationURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("MacOptimizationTool_Setup.dmg")

                try? FileManager.default.removeItem(at: destinationURL)
                try FileManager.default.moveItem(at: downloadedTempURL, to: destinationURL)

                self.downloadProgress = 0.92
                self.statusMessage = t("update.status.verifying")

                let actualHash = await Task.detached(priority: .userInitiated) {
                    UpdateVerification.sha256Hex(of: destinationURL)
                }.value

                guard UpdateVerification.matchesDigest(actual: actualHash, expected: expectedSHA256) else {
                    // 검증 실패 또는 다이제스트 미제공 -> 자동 마운트하지 않는다.
                    try? FileManager.default.removeItem(at: destinationURL)
                    self.isDownloading = false
                    self.downloadProgress = 0.0
                    self.statusMessage = expectedSHA256 == nil
                        ? t("update.status.noDigest")
                        : t("update.status.verifyFailed")
                    NSWorkspace.shared.open(Self.releasesPageURL)
                    return
                }

                self.statusMessage = t("update.status.mounting")

                let mounted = await Task.detached(priority: .userInitiated) { () -> Bool in
                    let process = Process()
                    process.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
                    process.arguments = ["attach", destinationURL.path, "-autoopen"]
                    do {
                        try process.run()
                        process.waitUntilExit()
                        return process.terminationStatus == 0
                    } catch {
                        return false
                    }
                }.value

                self.downloadProgress = mounted ? 1.0 : 0.0
                self.isDownloading = false
                self.statusMessage = mounted ? t("update.status.done") : t("update.status.mountFailed")
                if !mounted {
                    NSWorkspace.shared.activateFileViewerSelecting([destinationURL])
                }
            } catch {
                self.isDownloading = false
                self.downloadProgress = 0.0
                self.statusMessage = String(format: t("update.status.failed"), error.localizedDescription)
                NSWorkspace.shared.open(Self.releasesPageURL)
            }
        }
    }

    private func startDownloadWithProgress(url: URL) async throws -> URL {
        return try await withCheckedThrowingContinuation { continuation in
            let config = URLSessionConfiguration.default
            config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            config.timeoutIntervalForRequest = 30
            config.timeoutIntervalForResource = 300
            config.httpAdditionalHeaders = [
                "User-Agent": "MacOptimizationTool/\(Self.currentVersion)",
                "Accept": "application/octet-stream"
            ]

            let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
            var request = URLRequest(url: url)
            request.timeoutInterval = 30

            self.downloadContinuation = continuation
            let task = session.downloadTask(with: request)
            self.downloadTask = task
            task.resume()
        }
    }

    // MARK: - URLSessionDownloadDelegate

    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".dmg")
        let moveError: Error? = {
            do {
                try FileManager.default.moveItem(at: location, to: tempDir)
                return nil
            } catch {
                return error
            }
        }()

        Task { @MainActor in
            if let moveError {
                self.downloadContinuation?.resume(throwing: moveError)
            } else {
                self.downloadContinuation?.resume(returning: tempDir)
            }
            self.downloadContinuation = nil
        }
    }

    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            Task { @MainActor in
                self.downloadContinuation?.resume(throwing: error)
                self.downloadContinuation = nil
            }
        }
    }

    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        let writtenMB = Double(totalBytesWritten) / (1024.0 * 1024.0)
        let totalMB = Double(totalBytesExpectedToWrite) / (1024.0 * 1024.0)

        Task { @MainActor in
            self.downloadProgress = min(0.90, max(0.01, progress * 0.90))
            self.statusMessage = String(format: t("update.status.downloading"), writtenMB, totalMB, progress * 100)
        }
    }
}
