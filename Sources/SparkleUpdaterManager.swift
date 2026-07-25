import Foundation
import AppKit

struct UpdateCheckResult {
    let hasNewVersion: Bool
    let latestVersion: String
    let message: String
    let downloadURL: URL?
}

@MainActor
final class SparkleUpdaterManager: NSObject, ObservableObject {
    static let shared = SparkleUpdaterManager()

    @Published var isDownloading: Bool = false
    @Published var downloadProgress: Double = 0.0
    @Published var statusMessage: String = ""

    private override init() {
        super.init()
    }

    func checkForUpdates(completion: @escaping (UpdateCheckResult) -> Void) {
        // Sparkle / GitHub API check
        let apiURL = URL(string: "https://api.github.com/repos/crazy-vincnet/MacOptimizationTool/releases/latest")!
        
        var request = URLRequest(url: apiURL)
        request.timeoutInterval = 5

        Task {
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let latestTag = json["tag_name"] as? String,
                   let assets = json["assets"] as? [[String: Any]] {
                    
                    // DMG 설치 파일 direct download URL 탐색
                    var dmgDownloadURL: URL? = nil
                    for asset in assets {
                        if let name = asset["name"] as? String, name.hasSuffix(".dmg"),
                           let browserDownloadUrl = asset["browser_download_url"] as? String {
                            dmgDownloadURL = URL(string: browserDownloadUrl)
                            break
                        }
                    }
                    
                    let currentVersion = "v1.0.1"
                    let cleanTag = latestTag.starts(with: "v") ? latestTag : "v\(latestTag)"
                    
                    if cleanTag.compare(currentVersion, options: .numeric) == .orderedDescending {
                        let finalDownloadURL = dmgDownloadURL ?? URL(string: "https://github.com/crazy-vincnet/MacOptimizationTool/releases/download/\(cleanTag)/MacCleanOptimizer_Setup.dmg")!
                        let result = UpdateCheckResult(
                            hasNewVersion: true,
                            latestVersion: cleanTag,
                            message: "🎉 새로운 버전(\(cleanTag))이 출시되었습니다!\n\n[지금 자동 다운로드 & 설치] 버튼을 누르시면 앱 내에서 설치 파일(.dmg)을 직접 다운로드받아 즉시 마운트해 드립니다.",
                            downloadURL: finalDownloadURL
                        )
                        completion(result)
                        return
                    }
                }
                
                completion(UpdateCheckResult(hasNewVersion: false, latestVersion: "v1.0.1", message: t("settings.updateAlert"), downloadURL: nil))
            } catch {
                completion(UpdateCheckResult(hasNewVersion: false, latestVersion: "v1.0.1", message: t("settings.updateAlert"), downloadURL: nil))
            }
        }
    }

    /// 인앱 직접 다운로드 및 .dmg 자동 마운트/설행
    func startDirectDownloadAndInstall(from downloadURL: URL) {
        self.isDownloading = true
        self.downloadProgress = 0.15
        self.statusMessage = "최신 설치 파일(.dmg) 인앱 다운로드 중..."

        Task {
            do {
                let (tempLocalURL, _) = try await URLSession.shared.download(from: downloadURL)
                let destinationURL = FileManager.default.temporaryDirectory.appendingPathComponent("MacCleanOptimizer_Setup.dmg")
                
                try? FileManager.default.removeItem(at: destinationURL)
                try FileManager.default.moveItem(at: tempLocalURL, to: destinationURL)

                await MainActor.run {
                    self.downloadProgress = 0.85
                    self.statusMessage = "설치 디스크 자동 마운트 및 실행 중..."
                }

                // hdiutil을 이용하여 DMG 디스크 마운트 및 창 자동 오픈
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
                process.arguments = ["attach", destinationURL.path, "-autoopen"]
                try process.run()
                process.waitUntilExit()

                await MainActor.run {
                    self.downloadProgress = 1.0
                    self.isDownloading = false
                    self.statusMessage = "다운로드 및 마운트 완료!"
                }
            } catch {
                await MainActor.run {
                    self.isDownloading = false
                    self.statusMessage = "다운로드 실패: \(error.localizedDescription)"
                    // Fallback to browser
                    NSWorkspace.shared.open(downloadURL)
                }
            }
        }
    }
}
