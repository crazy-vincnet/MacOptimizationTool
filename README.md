<div align="center">

![App Icon](AppIcon.png)

# ⚡ Mac Clean Optimizer (Lab98 Studio Edition) v1.4.0

**macOS 전용 프리미엄 고성능 시스템 최적화, 디스크 정리 및 개인정보 보호 툴키트**

[![macOS](https://img.shields.io/badge/macOS-13.0%2B-000000?style=for-the-badge&logo=apple&logoColor=white)](https://www.apple.com/macos)
[![Swift](https://img.shields.io/badge/Swift-5.9-F05138?style=for-the-badge&logo=swift&logoColor=white)](https://swift.org)
[![Version](https://img.shields.io/badge/Version-v1.4.0-3ECF8E?style=for-the-badge)](https://github.com/crazy-vincnet/MacOptimizationTool/releases)
[![License](https://img.shields.io/badge/License-MIT-059669?style=for-the-badge)](LICENSE)

---

</div>

## 📌 주요 특징 (Key Features)

- **📊 실시간 시스템 대시보드 (Real-time Dashboard)**:
  - CPU, GPU, 메모리(App/Wired/Compressed), 디스크, 시스템 온도 및 배터리 전원 상태 실시간 모니터링
  - 메모리 가상 공간 및 캐시 수거를 위한 **원클릭 메모리 즉시 최적화** 및 프로세스 자원 폭주 경고 가드

- **🛡️ 시스템 전체 디스크 접근 권한 온보딩 (Full Disk Access Onboarding)**:
  - TCC `FileHandle` 정밀 샌드박스 검사 엔진 적용 (`PermissionManager`)
  - 필수 권한(전체 디스크 접근 권한) 미승인 시 직관적인 시스템 설정 가이드 모달 제공 (`PermissionModalView`)
  - macOS 프로세스 캐시 갱신을 위한 **앱 자동 재시작** 및 **즉시 시작(Bypass)** 지원

- **🛑 전 기능 비동기 스캔 즉시 취소 (Scan Cancellation)**:
  - 중복 파일, 대용량 파일, 정크 디스크 청소, 방치된 다운로드, 개인정보 등 **모든 탐색 메뉴에 [스캔 취소] 연동**
  - Swift Concurrency Task 캔슬 엔진 결합으로 언제든지 즉시 중단 및 화면 복구

- **⚡ 16-Worker 병렬 해시 & 초고속 다운로드 분류기**:
  - `maxConcurrency = 16` 슬라이딩 윈도우 기반 중복 파일 1차 해시 속도 극대화
  - `~/Downloads` 1단계 직속 방치 파일 0.001초 초고속 탐색 옵션

- **🗑️ 4단계 스마트 앱 완전 삭제기 (4-Tier Smart Uninstaller)**:
  - Pre-Authorization 사전 검증 (`FileSafety.deleteBatch`)으로 안전성 강화
  - 관리자 권한 승격 지원 및 잔여 찌꺼기 파일(Library/Caches, Application Support 등) 완벽 제거

- **🔒 브라우저 개인정보 정리기 (Privacy Cleaner)**:
  - Safari, Chrome, Edge, Firefox, Brave 등 웹 캐시, 쿠키, 로컬 스토리지 안전 수거

- **🔄 Sparkle 2 초고속 CDN 인앱 자동 업데이트 (Auto-Updater)**:
  - CDN 전용 스트리밍 세션 구현으로 100Mbps+ 초고속 다운로드 및 **실시간 MB / 퍼센트 진행률** 제공

- **☀️ 동적 라이트 / 다크 테마 및 4개 국어 지원**:
  - **한국어**, **English**, **简体中文**, **日本語** 네이티브 언어 지원 및 실시간 테마 반응

---

## 🛠️ 빌드 및 패키징 명령어 (Build & Packaging)

프로젝트 루트에서 제공되는 자동화 빌드 스크립트를 통해 손쉽게 실행 파일 및 설치 패키지를 생성할 수 있습니다:

### 1. 로컬 개발 및 앱 실행
```bash
./build.sh
```
Compiles all Swift sources, applies ad-hoc codesign, and launches `MacOptimizationTool.app`.

### 2. 웹 배포용 `.dmg` 디스크 이미지 패키징
```bash
./build_dmg.sh
```
Creates `MacOptimizationTool_Setup.dmg` with drag-and-drop `/Applications` installer folder.

### 3. Mac App Store 제출용 `.pkg` 패키징
```bash
./build_appstore_package.sh
```
Applies App Sandbox (`MacCleanOptimizer.entitlements`) and compiles `MacCleanOptimizer_AppStore.pkg` for App Store Connect.

---

## 📁 프로젝트 구조 (Project Architecture)

```
MacOptimizationTool/
├── Sources/                       # Swift 소스 코드
│   ├── App.swift                  # AppDelegate & 메뉴바 아이콘 연동
│   ├── MainView.swift             # 메인 윈도우 레이아웃 & 서브 탭 라우팅
│   ├── PermissionManager.swift    # FDA (필수) & 알림 (선택) TCC 검사기
│   ├── PermissionModalView.swift  # 권한 안내 Glassmorphism 온보딩 모달
│   ├── DashboardView.swift        # 실시간 자원 대시보드 뷰
│   ├── UninstallerView.swift      # 앱 완전 삭제기 뷰 & 드롭존
│   ├── UninstallerViewModel.swift # 앱 및 찌꺼기 파일 탐색 로직
│   ├── DiskCleanerView.swift      # 캐시 & 로그 디스크 정리 뷰
│   ├── LargeFilesView.swift       # 대용량 파일 검사기
│   ├── DuplicateView.swift        # 중복 파일 16-Worker 이진 해시 비교기
│   ├── PrivacyCleanerView.swift   # 브라우저 개인정보 및 쿠키 정리기
│   ├── OldDownloadsView.swift     # 방치된 다운로드 분류기
│   ├── SettingsView.swift         # 스튜디오 통일 레이아웃 설정 뷰
│   ├── Theme.swift                # 동적 dynamicProvider 디자인 토큰 사양
│   ├── LanguageManager.swift      # 4개 국어 번역 사원 및 헬퍼
│   ├── FileSafety.swift           # 4단계 폴백 안전 파일 삭제 엔진
│   └── SparkleUpdaterManager.swift# 초고속 CDN 인앱 자동 업데이트 관리자
├── docs/                          # GitHub Pages 공식 랜딩 페이지 웹사이트
│   ├── index.html                 # 모던 웹 디자인 사이트 HTML/CSS/JS
│   └── AppIcon.png                # 웹사이트용 로고 자산
├── AppIcon.icns                   # macOS 멀티레이어 아이콘 컴파일본
├── build.sh                       # 기본 컴파일 & 서명 빌드 스크립트
├── build_dmg.sh                   # 웹 배포용 DMG 빌드 스크립트
└── README.md                      # 프로젝트 설명서
```

---

## 📄 카피라이트 및 라이선스 (Copyright & License)

**Copyright © 2026 Lab98 Studio. All rights reserved.**  
Designed & Engineered for macOS by Vincent Jeon @ Lab98 Studio.
