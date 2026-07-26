import Foundation

/// 스캔 대상에서 제외할 트리 규칙.
///
/// 기존 중복 검사기는 `path.contains("/Library")` 로 걸렀다. 두 가지 문제가 있었다.
/// 1. 이미 그 트리 안으로 전부 내려간 뒤에 결과만 버려서, 열거·`stat` 비용을 그대로 낸다.
/// 2. 부분 문자열 비교라 사용자가 만든 `~/Projects/Library` 같은 폴더도 통째로 제외된다.
///
/// 여기서는 **디렉터리 진입 전에** 판정할 수 있는 형태로 규칙을 제공하고,
/// 절대 경로 비교는 경로 경계 단위로 수행한다.
public enum ScanExclusion {

    /// 이름만으로 가지치기하는 디렉터리.
    /// 캐시·의존성·빌드 산출물이라 중복이 많지만 사용자가 지울 대상이 아니고,
    /// 개발자 홈에서는 전체 파일 수의 대부분을 차지한다.
    public static let prunedDirectoryNames: Set<String> = [
        "node_modules",
        ".git",
        ".svn",
        ".hg",
        ".build",
        "build",
        "DerivedData",
        "Pods",
        "Carthage",
        ".venv",
        "venv",
        ".tox",
        "__pycache__",
        ".gradle",
        ".npm",
        ".yarn",
        ".pnpm-store",
        ".cache",
        ".cargo",
        ".rustup",
        "Caches",
        ".Trash",
        ".gemini",
        ".terraform",
        ".next",
        ".nuxt",
        ".parcel-cache",
        "Xcode",
        "vendor/bundle"
    ]

    /// 어떤 경우에도 스캔하지 않는 절대 경로 트리.
    public static let excludedAbsoluteTrees: [String] = [
        "/System",
        "/Library",
        "/private",
        "/usr",
        "/bin",
        "/sbin",
        "/opt",
        "/cores",
        "/dev",
        "/Volumes/Recovery"
    ]

    /// 홈 디렉터리 기준으로 제외할 하위 트리.
    /// `~/Library` 는 앱 컨테이너·캐시·메일·사진 라이브러리가 모여 있어 파일 수가 매우 많다.
    public static let excludedHomeSubpaths: [String] = [
        "Library",
        ".Trash",
        ".cache",
        ".npm",
        ".cargo",
        ".rustup",
        ".gradle",
        ".docker",
        ".orbstack"
    ]

    /// 디렉터리 이름만으로 가지치기할지 여부. 열거자가 그 안으로 내려가기 전에 호출한다.
    public static func shouldPruneDirectory(named name: String) -> Bool {
        prunedDirectoryNames.contains(name)
    }

    /// 경로 경계 단위 트리 포함 검사. `/usr` 가 `/usrdata` 를 잡지 않는다.
    public static func isWithinTree(path: String, tree: String) -> Bool {
        let p = normalized(path)
        let t = normalized(tree)
        if p == t { return true }
        return p.hasPrefix(t + "/")
    }

    /// 절대 경로 기준 제외 대상인지. 홈 하위 제외 트리도 함께 판정한다.
    public static func isExcluded(path: String, homeDirectory: String = NSHomeDirectory()) -> Bool {
        for tree in excludedAbsoluteTrees where isWithinTree(path: path, tree: tree) {
            return true
        }
        for sub in excludedHomeSubpaths where isWithinTree(path: path, tree: normalized(homeDirectory) + "/" + sub) {
            return true
        }
        return false
    }

    /// 후행 슬래시를 제거하고 중복 슬래시를 접는다.
    private static func normalized(_ path: String) -> String {
        var result = (path as NSString).standardizingPath
        while result.count > 1 && result.hasSuffix("/") {
            result.removeLast()
        }
        return result
    }
}
