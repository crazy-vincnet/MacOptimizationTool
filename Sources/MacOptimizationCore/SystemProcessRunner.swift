import Foundation

/// 외부 시스템 명령을 실행하고 시작 실패와 비정상 종료를 일관되게 처리한다.
public enum SystemProcessRunner {
    /// 명령이 정상적으로 시작되고 종료 코드 0으로 끝났을 때만 `true`를 반환한다.
    @discardableResult
    public static func run(executableURL: URL, arguments: [String] = []) -> Bool {
        let path = executableURL.path
        guard FileManager.default.isExecutableFile(atPath: path) else {
            print("실행 파일을 사용할 수 없습니다: \(path)")
            return false
        }

        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            print("명령 실행 실패 (\(path)): \(error.localizedDescription)")
            return false
        }
    }
}
