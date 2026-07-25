import Foundation
import AppKit

struct UpdateCheckResult {
    let hasNewVersion: Bool
    let latestVersion: String
    let message: String
    let downloadURL: URL?
}

@MainActor
final class SparkleUpdaterManager: NSObject, ObservableObject, URLSessionDownloadDelegate {
    static let shared = SparkleUpdaterManager()

    @Published var isDownloading: Bool = false
    @Published var downloadProgress: Double = 0.0
    @Published var statusMessage: String = ""

    private var downloadTask: URLSessionDownloadTask?
    private var downloadContinuation: CheckedContinuation<URL, Error>?

    private override init() {
        super.init()
    }

    func checkForUpdates(completion: @escaping (UpdateCheckResult) -> Void) {
        let apiURL = URL(string: "https://api.github.com/repos/crazy-vincnet/MacOptimizationTool/releases/latest")!
        
        var request = URLRequest(url: apiURL)
        request.timeoutInterval = 10
        request.setValue("MacOptimizationTool/v1.4.0", forHTTPHeaderField: "User-Agent")

        Task {
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let latestTag = json["tag_name"] as? String,
                   let assets = json["assets"] as? [[String: Any]] {
                    
                    var dmgDownloadURL: URL? = nil
                    for asset in assets {
                        if let name = asset["name"] as? String, name.hasSuffix(".dmg"),
                           let browserDownloadUrl = asset["browser_download_url"] as? String {
                            dmgDownloadURL = URL(string: browserDownloadUrl)
                            break
                        }
                    }
                    
                    let rawAppVer = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.4.0"
                    let cleanCurrent = rawAppVer.replacingOccurrences(of: "v", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                    let cleanTag = latestTag.replacingOccurrences(of: "v", with: "").trimmingCharacters(in: .whitespacesAndNewlines)

                    if (cleanTag as NSString).compare(cleanCurrent, options: .numeric) == .orderedDescending {
                        let displayTag = "v\(cleanTag)"
                        let finalDownloadURL = dmgDownloadURL ?? URL(string: "https://github.com/crazy-vincnet/MacOptimizationTool/releases/download/\(displayTag)/MacOptimizationTool_Setup.dmg")!
                        let result = UpdateCheckResult(
                            hasNewVersion: true,
                            latestVersion: displayTag,
                            message: "🎉 새로운 버전(\(displayTag))이 출시되었습니다!\n\n[지금 자동 다운로드 & 설치] 버튼을 누르시면 최신 설치 파일(.dmg)을 초고속 인앱 다운로드받아 즉시 마운트해 드립니다.",
                            downloadURL: finalDownloadURL
                        )
                        completion(result)
                        return
                    }

                }
                
                let appVer = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.4.0"
                let currentVerString = "v\(appVer)"
                let formattedMsg = String(format: t("settings.updateAlert"), appVer)
                completion(UpdateCheckResult(hasNewVersion: false, latestVersion: currentVerString, message: formattedMsg, downloadURL: nil))
            } catch {
                let appVer = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.4.0"
                let currentVerString = "v\(appVer)"
                let formattedMsg = String(format: t("settings.updateAlert"), appVer)
                completion(UpdateCheckResult(hasNewVersion: false, latestVersion: currentVerString, message: formattedMsg, downloadURL: nil))
            }
        }
    }

    /// 초고속 병렬 스트리밍 인앱 다운로드 및 .dmg 자동 마운트/실행
    func startDirectDownloadAndInstall(from downloadURL: URL) {
        self.isDownloading = true
        self.downloadProgress = 0.01
        self.statusMessage = "최신 설치 파일(.dmg) 초고속 서버 접속 중..."

        Task {
            do {
                let downloadedTempURL = try await startDownloadWithProgress(url: downloadURL)
                let destinationURL = FileManager.default.temporaryDirectory.appendingPathComponent("MacOptimizationTool_Setup.dmg")
                
                try? FileManager.default.removeItem(at: destinationURL)
                try FileManager.default.moveItem(at: downloadedTempURL, to: destinationURL)

                await MainActor.run {
                    self.downloadProgress = 0.92
                    self.statusMessage = "설치 디스크 자동 마운트 및 창 오픈 중..."
                }

                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
                process.arguments = ["attach", destinationURL.path, "-autoopen"]
                try process.run()
                process.waitUntilExit()

                await MainActor.run {
                    self.downloadProgress = 1.0
                    self.isDownloading = false
                    self.statusMessage = "다운로드 및 디스크 마운트 완료!"
                }
            } catch {
                await MainActor.run {
                    self.isDownloading = false
                    self.statusMessage = "다운로드 실패: \(error.localizedDescription)"
                    NSWorkspace.shared.open(downloadURL)
                }
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
                "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
                "Accept": "*/*"
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
        try? FileManager.default.moveItem(at: location, to: tempDir)
        
        Task { @MainActor in
            self.downloadContinuation?.resume(returning: tempDir)
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
            self.statusMessage = String(format: "다운로드 중... (%.1f MB / %.1f MB - %.0f%%)", writtenMB, totalMB, progress * 100)
        }
    }
}
