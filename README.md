<div align="center">

![App Icon](AppIcon.png)

# ⚡ Mac Clean Optimizer (Lab98 Studio Edition)

**macOS 전용 프리미엄 고성능 시스템 최적화 및 디스크 정리 툴키트**

[![macOS](https://img.shields.io/badge/macOS-14.0%2B-000000?style=for-the-badge&logo=apple&logoColor=white)](https://www.apple.com/macos)
[![Swift](https://img.shields.io/badge/Swift-5.9-F05138?style=for-the-badge&logo=swift&logoColor=white)](https://swift.org)
[![License](https://img.shields.io/badge/License-MIT-059669?style=for-the-badge)](LICENSE)
[![Build Status](https://img.shields.io/badge/Build-Passing-3ECF8E?style=for-the-badge)](build.sh)

---

</div>

## 📌 주요 특징 (Key Features)

- **📊 실시간 시스템 대시보드 (Real-time Dashboard)**:
  - CPU, GPU, 메모리(App/Wired/Compressed), 디스크, 시스템 온도 및 배터리 전원 상태 실시간 모니터링
  - 메모리 가상 공간 및 캐시 수거를 위한 **원클릭 메모리 즉시 최적화**

- **🗑️ 4단계 스마트 앱 완전 삭제기 (4-Tier Smart Uninstaller)**:
  - 일반 삭제부터 관리자 권한(`with administrator privileges`) 승격까지 4단계 폴백 엔진 적용
  - 시스템 및 루트 소유 앱도 잔여 찌꺼기 파일(Library/Caches, Application Support 등)까지 완벽하게 추적하여 안전 제거

- **🧹 시스템 & 사용자 디스크 정리기 (Disk Cleaner)**:
  - 시스템 캐시, 로그, Xcode DerivedData, 휴지통 낭비 공간 탐색 및 안전 청소

- **🔍 대용량 & 중복 파일 정리 (Large Files & Duplicate Finder)**:
  - 디렉토리 이진 해시 비교 기반 중복 파일 고속 탐색 및 대용량 방치 파일 분류

- **☀️ 동적 라이트 / 다크 테마 엔진 (Dynamic Theme Engine)**:
  - **라이트 모드(기본값)**, **다크 모드**, **macOS 시스템 설정 맞춤** 실시간 반응
  - 서체 앤티앨리어싱을 위한 단색 카드 배경 및 `#020617` 고대비 텍스트 적용 (눈이 편안한 디자인)

- **🌐 4개 국어 완전 로컬라이제이션 (Native Localization)**:
  - **한국어**, **English**, **简体中文**, **日本語** 네이티브 언어 지원

- **🔄 Sparkle 2 인앱 자동 업데이트 (Auto-Updater)**:
  - 업계 표준 Sparkle 2 연동으로 앱 내 원클릭 버전 확인 및 자동 업데이트

---

## 🛠️ 빌드 및 패키징 명령어 (Build & Packaging)

프로젝트 루트에서 제공되는 자동화 빌드 스크립트를 통해 손쉽게 실행 파일 및 설치 패키지를 생성할 수 있습니다:

### 1. 로컬 개발 및 앱 실행
```bash
./build.sh
```
Compiles all Swift sources, applies ad-hoc codesign, and launches `MacCleanOptimizer.app`.

### 2. 웹 배포용 `.dmg` 디스크 이미지 패키징
```bash
./build_dmg.sh
```
Creates `MacCleanOptimizer_Setup.dmg` with drag-and-drop `/Applications` installer folder.

### 3. Mac App Store 제출용 `.pkg` 패키징
```bash
./build_appstore_package.sh
```
Applies App Sandbox (`MacCleanOptimizer.entitlements`) and compiles `MacCleanOptimizer_AppStore.pkg` for App Store Connect / Transporter upload.

### 4. 1024x1024 고해상도 앱 아이콘 재컴파일
```bash
./generate_icns.sh
```
Generates 10 multi-resolution PNGs and compiles `AppIcon.icns` using macOS `iconutil`.

---

## 📁 프로젝트 구조 (Project Architecture)

```
MacOptimizationTool/
├── Sources/                       # Swift 소스 코드
│   ├── App.swift                  # AppDelegate & 메뉴바 아이콘 연동
│   ├── MainView.swift             # 메인 윈도우 레이아웃 & 서브 탭 라우팅
│   ├── DashboardView.swift        # 실시간 자원 대시보드 뷰
│   ├── UninstallerView.swift      # 앱 완전 삭제기 뷰 & 드롭존
│   ├── UninstallerViewModel.swift # 앱 및 찌꺼기 파일 탐색 로직
│   ├── DiskCleanerView.swift      # 캐시 & 로그 디스크 정리 뷰
│   ├── LargeFilesView.swift       # 대용량 파일 검사기
│   ├── DuplicateView.swift        # 중복 파일 이진 해시 비교기
│   ├── SettingsView.swift         # 스튜디오 통일 레이아웃 설정 뷰
│   ├── SettingsViewModel.swift    # 설정 상태 및 업데이트 관리
│   ├── Theme.swift                # 동적 dynamicProvider 디자인 토큰 사양
│   ├── LanguageManager.swift      # 4개 국어 번역 사원 및 헬퍼
│   ├── FileSafety.swift           # 4단계 폴백 안전 파일 삭제 엔진
│   └── SparkleUpdaterManager.swift# Sparkle 2 자동 업데이트 관리자
├── AppIcon.icns                   # macOS 멀티레이어 아이콘 컴파일본
├── MacCleanOptimizer.entitlements # App Sandbox 보안 권한 명세
├── appcast.xml                    # Sparkle 2 자동 업데이트 RSS 피드 템플릿
├── build.sh                       # 기본 컴파일 & 서명 빌드 스크립트
├── build_dmg.sh                   # 웹 배포용 DMG 빌드 스크립트
├── build_appstore_package.sh      # App Store 제출용 PKG 빌드 스크립트
└── README.md                      # 프로젝트 설명서
```

---

## 📄 카피라이트 및 라이선스 (Copyright & License)

**Copyright © 2026 Lab98 Studio. All rights reserved.**  
Designed & Engineered for macOS by Vincent Jeon @ Lab98 Studio.
