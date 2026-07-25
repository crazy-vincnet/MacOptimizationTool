# MacOptimizationTool 코드 분석 리포트

- 분석일: 2026-07-25
- 대상 커밋: `3f39627` (main)
- 범위: `Sources/*.swift` 40개 파일 / 10,651줄, 빌드·릴리스 스크립트, 배포 메타데이터
- 빌드 검증: `swiftc -O -parse-as-library` 클린 통과, 경고 0. Swift 6 모드에서는 에러 4건(`vm_kernel_page_size` 공유 가변 상태).

---

## 1. 구조 개요

MVVM SwiftUI 앱. `Package.swift` 없이 `build.sh`가 `swiftc`로 40개 파일을 한 번에 통짜 컴파일한다.

| 레이어 | 파일 | 비고 |
|---|---|---|
| 진입 | `App.swift`, `MainView.swift` | 사이드바 12탭 라우팅 |
| 기능 VM/View 쌍 | 11쌍 | Uninstaller, DiskClean, LargeFiles, Duplicate, Privacy, OldDownloads, DiskHealth, Startup, WinCompat, Maintenance, Settings |
| 공용 | `FileSafety`, `HardwareStatsHelper`, `PermissionManager`, `Theme`, `Models` | `FileSafety`가 삭제 로직 단일 소스 |
| 인프라 | `LanguageManager` + `GeneratedTranslations`(909줄), `MenuBarManager`, `ProcessGuardManager`, `SparkleUpdaterManager` | |

**잘된 점**: 삭제 로직을 `FileSafety`로 통합, 보호 경로 이중화(exact/tree), 심볼릭 링크 해석 후 경로 비교, 전 스캔 `Task.cancel()` 연동, 4개 언어 사전 병합 구조, 컴파일 경고 0.

---

## 2. 심각 (보안)

### 2.1 AppleScript 인젝션 → root 임의 명령 실행
`Sources/FileSafety.swift:75-76`, `Sources/FileSafety.swift:143-144`

```swift
let escapedPath = url.path.replacingOccurrences(of: "'", with: "'\\''")
let script = "do shell script \"rm -rf '\(escapedPath)'\" with administrator privileges"
```

이스케이프가 셸 레이어만 처리하고 AppleScript 문자열 레이어(`"`, `\`)는 처리하지 않는다. 파일명에 `"` 또는 `\`가 들어가면 AppleScript 문자열을 탈출할 수 있고, 그 결과가 `with administrator privileges`로 실행되어 root 권한 임의 명령 실행이 된다. 파일명은 다운로드 파일·앱 번들 내부 잔여물 등 외부에서 정해지는 값이다.

### 2.2 root `rm -rf` + 느슨한 매칭 조합
`Sources/FileSafety.swift:68-86`, `Sources/UninstallerViewModel.swift:282,303-344`

- 관리자 대상 판정이 `p.hasPrefix("/library") || !fm.isWritableFile(...)` 로, `/Library` 전체 하위가 root `rm -rf` 대상이 된다.
- 이 경로에는 `isProtectedExact`만 적용되고 `isProtectedTree`는 적용되지 않는다(`deleteBatch:61`).
- 대상 선정은 `matchesStatic` 휴리스틱(토큰 분리 매칭)이라 오탐이 가능하다. 오탐 1건이 `/Library/LaunchDaemons/...` 같은 항목을 잡으면 휴지통을 거치지 않는 영구 root 삭제가 된다.
- README는 "휴지통 수거"로 설명하지만 관리자 경로는 휴지통을 거치지 않아 복구가 불가능하다.

### 2.3 업데이트 무결성 검증 없음
`Sources/SparkleUpdaterManager.swift:98-112`

DMG를 받은 즉시 `hdiutil attach -autoopen`을 실행한다. 체크섬·서명·공증 검증이 전혀 없다. 클래스명은 Sparkle이지만 Sparkle을 사용하지 않아 EdDSA 검증도 없다. 앱 자체도 ad-hoc 서명이다. 릴리스 자산이 교체되면 그대로 실행된다. `appcast.xml`은 v1.3.0에서 멈춘 데드 파일이며 DMG 이름도 구버전(`MacCleanOptimizer_Setup.dmg`)이다.

---

## 3. 높음 (버그)

| 위치 | 문제 |
|---|---|
| `StartupManagerViewModel.swift:114-116` | `@MainActor`에서 `FileSafety.moveToTrash`를 동기 호출. 내부 `semaphore.wait(2.0)`(`FileSafety.swift:124-131`)와 관리자 AppleScript 프롬프트가 메인 스레드를 블로킹해 UI 프리즈/데드락 발생 |
| `HardwareStatsHelper.swift:16,54-68` | `static var previousCPULoad`가 비격리 가변 상태. 텔레메트리 스트림과 `MenuBarManager.swift:73-77`의 `Task.detached`가 동시 접근해 데이터 레이스 |
| `HardwareStatsHelper.swift:52,69,95` | 실패 시 CPU `5.0`, RAM `60%`라는 가짜 값을 반환. 모니터링 도구가 조용히 거짓 수치를 표시 |
| `DiskCleanViewModel.swift:84-89` | `~/.Trash`를 정크 카테고리로 두고 `moveToTrash`로 삭제 시도. 휴지통 항목을 휴지통으로 옮기는 동작이라 실제 공간 회수가 없다 |
| `release.sh:26-27` | `sed "s/<string>1\.[0-9]\.[0-9]<\/string>/"` 가 한 자리 숫자를 가정. v1.10.0 / v2.x에서 버전 치환 실패 |
| `MacCleanOptimizer.entitlements` vs `build.sh:80-84` | entitlements는 `app-sandbox: true`인데 `build.sh`는 `--entitlements`를 전달하지 않는다. 샌드박스는 `/Library` 스캔·`Process()`·관리자 AppleScript와 비호환이라 App Store 패키지 경로에서는 기능 대부분이 동작하지 않는다 |
| `SparkleUpdaterManager.swift:51-52` | `replacingOccurrences(of: "v", ...)`가 문자열 내 모든 `v`를 제거. `1.0.0-dev` → `1.0.0-de` |

---

## 4. 중간 (데드코드 / 정합성)

- `ProcessGuardManager.swift:23,36-44` — `startGuard()` 본문이 전체 주석 처리되어 있고 `isGuardEnabled = false`. `inspectProcesses` / `handleHighResourceProcess` / `killAlertProcess`가 도달 불가. README는 "프로세스 폭주 파수꾼"을 동작하는 기능으로 광고 중이라 문서·실물 불일치.
- `App.swift:53-106` — `private func setupMenuBar()` 호출부 없음. `MenuBarManager`와 중복된 메뉴바 구현 54줄이 사문화. `telemetryTask`는 시작되지 않는데 `quitApp:150`에서 취소한다.
- `StartupView.swift` / `StartupViewModel.swift` — `StartupManagerView` / `StartupManagerViewModel`와 병존하지만 라우팅되는 것은 후자뿐. 전자는 완전 미사용.
- i18n 미완 — 번역 키 사용 464곳 대비 하드코딩 한국어 문자열 233곳. `MenuBarManager`, `DiskCleanViewModel` 상태 문구, `ProcessGuardManager`, `SparkleUpdaterManager` 메시지가 영어/중국어/일본어 사용자에게도 한국어로 노출.
- `SparkleUpdaterManager.swift:31` — User-Agent에 `v1.4.0` 하드코딩(앱은 1.5.0). `:137`은 Chrome User-Agent 위장.
- LICENSE 파일 없음 — README 배지는 MIT로 표기.

---

## 5. 인프라

- 테스트 0개, CI 없음. 파괴적 삭제 로직에 회귀 테스트가 없는 것이 구조적으로 가장 큰 리스크.
- `Package.swift` 없음 → 증분 빌드 불가, 40파일 매번 전체 컴파일.
- `build.sh:83` `codesign --deep` — Apple이 deprecated 처리한 옵션. ad-hoc 재서명마다 TCC 권한이 초기화되어 FDA 재승인이 반복된다.
- 워킹 트리에 3.6MB `.pkg`, `.app` 번들 2개, 2.2MB `.icns`, 1.3MB `.png` 방치(커밋은 `.gitignore`로 차단됨).
- `release.sh:36` `git add .` 무차별 스테이징.

---

## 6. 조치 결과 (2026-07-25)

| # | 항목 | 상태 |
|---|---|---|
| 2.1 | AppleScript 인젝션 | 수정 — AppleScript/셸 이중 이스케이프 헬퍼 도입 |
| 2.2 | root `rm -rf` 범위 | 수정 — `isProtectedTree` 적용 + `/Library` 화이트리스트 + 휴지통 우선 |
| 2.3 | 업데이트 무결성 | 수정 — HTTPS·호스트 허용목록·SHA-256 검증, 미검증 시 자동 마운트 차단 |
| 3.1 | 메인 스레드 블로킹 | 수정 — `removeItem` 비동기화 |
| 3.2 | CPU 상태 데이터 레이스 | 수정 — `NSLock` 보호 |
| 3.3 | 가짜 텔레메트리 폴백 | 수정 — 옵셔널 반환으로 전환 |
| 3.4 | `.Trash` 카테고리 | 수정 — 휴지통 내부 항목은 영구 삭제 경로 사용 |
| 3.5 | `release.sh` 버전 정규식 | 수정 — 다자리 버전 대응 |
| 3.6 | entitlements 충돌 | 수정 — 배포용/App Store용 entitlements 분리 |
| 3.7 | 버전 문자열 파싱 | 수정 — 선행 `v`만 제거 |
| 4.x | 데드코드·문서 불일치 | 수정 — 미사용 코드 제거, ProcessGuard 재활성화, 하드코딩 문자열 번역화, LICENSE 추가 |
| 추가 | Swift 6 strict concurrency | 수정 — 에러 4건 → 0건. `LanguageManager` 스레드 안전화, sending 클로저 3건, `DiskSunburstViewModel` 격리, `UNNotificationSettings` 전달 수정 |
| 5 | SPM 전환·테스트·CI | 수정 — 3개 타깃으로 분리, swift-testing 56개 테스트, GitHub Actions CI 추가 |

### 상세 조치 내역

**보안**
- `FileSafety.shellQuoted` + `appleScriptStringLiteral` 이중 이스케이프 헬퍼 도입. 백슬래시를 먼저 치환한 뒤 큰따옴표를 처리하며, 제어 문자가 포함된 경로는 `isShellSafePath` 로 아예 거부한다.
- `isDeletableLeftover` 신설: 보호 트리를 기본 차단하고 `elevatableLibrarySubtrees`(Application Support / Caches / Logs / Preferences / LaunchAgents / LaunchDaemons / PrivilegedHelperTools / Containers / Saved Application State / Internet Plug-Ins)의 **하위 항목만** 예외 허용한다. 트리 루트 자체는 대상이 되지 않는다.
- 업데이터는 HTTPS + GitHub 호스트 허용목록을 강제하고, GitHub Release API 의 `digest`(`sha256:...`)와 실제 파일 해시가 일치할 때만 `hdiutil attach` 를 실행한다. 다이제스트가 없으면 자동 설치를 중단하고 릴리스 페이지를 연다.
- `release.sh` 가 릴리스 노트에 DMG SHA-256 을 함께 게시한다.

**동작**
- `moveToTrash` 는 메인 스레드에서 `NSWorkspace.recycle` 세마포어 대기를 건너뛰고, `moveToTrashAsync` 래퍼를 통해 `@MainActor` 호출자가 안전하게 사용할 수 있다.
- 휴지통 내부 항목은 `permanentlyDelete` 경로로 처리해 실제로 공간을 회수한다.
- `HardwareStatsHelper` 는 `NSLock` 으로 CPU 틱 스냅샷을 보호하고, 측정 실패 시 옵셔널 `nil` 을 반환한다. 메뉴바는 수치 대신 `--` 를 표시한다.
- `ProcessGuardManager` 는 `Task` 기반 5초 주기 감시로 재활성화되었고, 임계값 상수를 판정과 문구가 공유한다. 사용자 설정은 `UserDefaults` 에 유지된다.

**정리**
- 삭제: `StartupView.swift`, `StartupViewModel.swift`, `appcast.xml`, `AppDelegate` 의 미사용 메뉴바 구현.
- 추가: `AdditionalTranslations.swift`(4개 언어 × 159키), `LICENSE`, `MacOptimizationTool.entitlements`.
- 경로는 이후 SPM 전환에 따라 `Sources/MacOptimizationCore/` · `Sources/MacOptimizationTool/` 로 이동했다.
- 하드코딩 한국어 UI 문자열 0건. 사용 중인 번역 키 414개 전부 정의됨.

### SPM 전환 상세

`swiftc` 단일 호출 방식을 SwiftPM 3-타깃 구조로 재편했다.

| 타깃 | 경로 | 내용 |
|---|---|---|
| `MacOptimizationCore` | `Sources/MacOptimizationCore/` | 삭제 안전 규칙, 잔여물 매칭, 업데이트 검증, 텔레메트리, 번역 |
| `MacOptimizationTool` | `Sources/MacOptimizationTool/` | SwiftUI 뷰·뷰모델·`@main` |
| `MacOptimizationCoreTests` | `Tests/MacOptimizationCoreTests/` | swift-testing 스위트 56개 |

- 세 타깃 모두 `swiftLanguageMode(.v6)` 로 고정해 strict concurrency 위반이 다시 들어오지 못하게 했다.
- 리뷰에서 위험도가 높다고 판단한 로직을 Core 로 추출했다: `LeftoverMatcher`(잔여물 오탐), `UpdateVerification`(버전·호스트·해시 검증).
- 빌드 스크립트 3종은 `swift build -c release --show-bin-path` 결과를 번들에 복사하는 방식으로 전환했다. 증분 빌드가 동작한다.
- `.github/workflows/ci.yml` 이 push/PR 마다 `swift build` → `./test.sh` → `./build.sh --no-run` → `codesign -v` 를 실행한다.

**전환 과정에서 새로 드러난 결함 2건**

1. `OldDownloadsView` 가 macOS 14 전용 `onChange(of:initial:_:)` 를 사용하고 있었다. 앱은 `LSMinimumSystemVersion 13.0` 을 선언하므로 macOS 13 에서 실패한다. `swiftc` 는 `-target` 없이 호스트 기준으로 컴파일해 이를 잡지 못했고, SwiftPM 의 `platforms: [.macOS(.v13)]` 이 잡아냈다. 버전 분기 `ViewModifier` 로 수정.
2. 번역 정합성 테스트가 `100% 전수 계산` 같은 리터럴 퍼센트를 포맷 지정자로 오인할 수 있음을 드러냈다. 테스트 카운터를 실제 변환 지정자만 세도록 정정했고, 언어 간 지정자 개수 불일치를 상시 검증한다.

**테스트 커버리지**

| 스위트 | 검증 내용 |
|---|---|
| `FileSafetyTests` | 보호 경로(정확/트리), 경로 경계, `/Library` 허용 트리 루트 제외, 셸·AppleScript 이중 이스케이프, 인젝션 시나리오, 제어 문자 거부, 해시 |
| `LeftoverMatcherTests` | 정상 매칭 및 오탐 방지(짧은 이름, 일반 명칭, 구분자 없는 접두사, 빈 번들 ID) |
| `UpdateVerificationTests` | 버전 정규화·비교, HTTPS/호스트 허용목록, 유사 도메인 거부, 다이제스트 파싱·대조, 파일 SHA-256 |
| `TranslationTests` | 4개 언어 키 집합 일치, 빈 값 없음, 포맷 지정자 개수 일치, 폴백 |
| `HardwareStatsTests` | RAM 통계 내부 일관성, CPU 범위, 스트림 방출 |

### 실행 방법

```bash
swift build          # 디버그 빌드
./test.sh            # 단위 테스트 (Xcode 미설치 환경 자동 대응)
./build.sh --no-run  # 릴리스 빌드 + .app 패키징 + 서명
```

`test.sh` 는 Xcode 없이 Command Line Tools 만 설치된 환경에서 SwiftPM 이 swift-testing 프레임워크를 찾지 못하는 문제를 우회한다.
