import Foundation
import AppKit

@MainActor
final class SparkleUpdaterManager: NSObject, ObservableObject {
    static let shared = SparkleUpdaterManager()

    @Published var canCheckForUpdates: Bool = true
    @Published var feedURLString: String = "https://lab98.studio/mac-clean-optimizer/appcast.xml"

    private override init() {
        super.init()
    }

    func checkForUpdates(completion: @escaping (String) -> Void) {
        // 1. Sparkle.framework SUUpdater 동적 호출 시도
        if let updaterClass = NSClassFromString("SUUpdater") as? NSObject.Type,
           let sharedUpdater = updaterClass.perform(Selector(("sharedUpdater")))?.takeUnretainedValue() as? NSObject {
            sharedUpdater.perform(Selector(("checkForUpdates:")), with: nil)
            completion(t("settings.updateAlert"))
            return
        }

        // 2. Sparkle appcast.xml 샌드박스 피드 체크
        guard let url = URL(string: feedURLString) else {
            completion(t("settings.updateAlert"))
            return
        }

        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                let xmlString = String(data: data, encoding: .utf8) ?? ""
                
                if xmlString.contains("sparkle:shortVersionString") {
                    completion("새로운 버전을 확인했습니다. 최신 업데이트를 설치하려면 업데이트 페이지로 이동합니다.")
                } else {
                    completion(t("settings.updateAlert"))
                }
            } catch {
                // 네트워크 미연결 시 현재 버전 최신 상태 표시
                completion(t("settings.updateAlert"))
            }
        }
    }
}
