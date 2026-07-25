<div align="center">

![App Icon](AppIcon.png)

# ⚡ Mac Clean Optimizer (Lab98 Studio Edition) v1.5.0

**macOS 전용 프리미엄 고성능 시스템 최적화, 디스크 정리, 자원 가드 및 개인정보 보호 종합 툴키트**

[![macOS](https://img.shields.io/badge/macOS-13.0%2B-000000?style=for-the-badge&logo=apple&logoColor=white)](https://www.apple.com/macos)
[![Swift](https://img.shields.io/badge/Swift-5.9-F05138?style=for-the-badge&logo=swift&logoColor=white)](https://swift.org)
[![Version](https://img.shields.io/badge/Version-v1.5.0-3ECF8E?style=for-the-badge)](https://github.com/crazy-vincnet/MacOptimizationTool/releases)
[![License](https://img.shields.io/badge/License-MIT-059669?style=for-the-badge)](LICENSE)

---

</div>

## 📖 목차 (Table of Contents)
1. [주요 기능 소개 (Core Features)](#-주요-기능-소개-core-features)
2. [핵심 모듈 동작 원리 (Architecture Deep Dive)](#-핵심-모듈-동작-원리-architecture-deep-dive)
3. [빌드 및 배포 스크립트 안내 (Build & Deployment)](#-빌드-및-배포-스크립트-안내-build--deployment)
4. [프로젝트 디렉토리 구조 (Project Structure)](#-프로젝트-디렉토리-구조-project-structure)
5. [라이선스 및 저작권 (License & Copyright)](#-라이선스-및-저작권-license--copyright)

---

## 📌 주요 기능 소개 (Core Features)

### 📊 1. 실시간 시스템 대시보드 & 자원 가드 (Real-time Dashboard & Resource Guard)
- **1초 단위 실시간 자원 감시**: CPU 사용량, GPU 로드, RAM(앱/Wired/압축 메모리), 디스크 여유 공간, 시스템 온도 및 배터리 전원 상태 실시간 표시.
- **원클릭 메모리 즉시 최적화**: macOS 빌트인 `purge` 기법과 연결하여 비활성 메모리 및 캐시 영역을 원클릭으로 안전 환수.
- **프로세스 폭주 파수꾼 (`ProcessGuardManager`)**: CPU 점유율 85% 이상 독점 앱 실시간 감지 및 경고 팝업, 원클릭 강제 종료 기능 제공.

### 🛡️ 2. 시스템 전체 디스크 접근 권한 온보딩 (Full Disk Access Onboarding)
- **TCC `FileHandle` 정밀 샌드박스 검사기 (`PermissionManager`)**: POSIX chmod 체크 대신 실시간 TCC 샌드박스 오픈 테스트를 통해 권한 부여 상태를 정확하게 판별.
- **차단형 온보딩 팝업 (`PermissionModalView`)**: 필수 권한(전체 디스크 접근 권한) 미승인 시 앱 접근을 안전하게 보호하고 안내.
- **프로세스 자동 재시작 & 수동 우회 버튼**:
  - `[앱 자동 재시작]`: macOS TCC 권한 토큰 즉시 반영을 위해 앱을 자동 종료 후 재실행.
  - `[권한 부여 완료 • 바로 시작하기]`: 수동 권한 스위치를 켠 경우 재시작 없이 즉시 앱 메인 화면 진입.

### 🛑 3. 전 기능 비동기 스캔 즉시 취소 (Scan Cancellation)
- **전 스캔 카드 [스캔 취소] 연동**: 중복 파일, 대용량 파일, 시스템 정크 디스크 청소, 방치된 다운로드, 브라우저 개인정보 정리 등 모든 스캔 카드 오버레이에 스캔 취소 버튼 연결.
- **Swift Concurrency `Task.cancel()` 엔진**: 탐색 수행 중 사용자가 취소 시 백그라운드 태스크를 즉시 중단하고 안전하게 이전 UI 상태로 복구.

### ⚡ 4. 16-Worker 병렬 해시 & 초고속 다운로드 분류기
- **`maxConcurrency = 16` 슬라이딩 윈도우 해시**: 중복 파일 비교 시 1차 고속 이진 해시 비교를 16개 전용 async 워커로 가속하여 디스크 I/O 교착상태 방지.
- **`~/Downloads` 0.001초 분류기**: `.skipsSubdirectoryDescendants` 옵션을 적용하여 다운로드 폴더 1단계 직속 파일만 초고속 탐색.

### 🗑️ 5. 4단계 스마트 앱 완전 삭제기 (4-Tier Smart Uninstaller)
- **Pre-Authorization 사전 권한 검증 (`FileSafety.deleteBatch`)**: 삭제 전 관리자 권한 필요 여부를 사전 점검하여, 비밀번호 오입력 시 앱이나 파일이 지워지는 오작동 완벽 차단.
- **4단계 폴백 삭제 엔진**: `Trash` ➔ `NSWorkspace` ➔ `Direct Delete` ➔ `Admin Elevation (with administrator privileges)`.
- **드롭존 1초 추적**: 앱 아이콘을 드롭존에 놓으면 `Application Support`, `Caches`, `Preferences` 잔여 찌꺼기 파일까지 완벽 추적.

### 🔒 6. 브라우저 개인정보 및 웹 찌꺼기 수거기 (Privacy Cleaner)
- **다중 브라우저 통합 수거**: Safari, Chrome, Edge, Firefox, Brave 웹 캐시, 쿠키, 로컬 스토리지, Favicon 캐시 탐색 및 안전 청소.

### 🚀 7. Sparkle 2 초고속 CDN 인앱 자동 업데이트 (Fast CDN Auto-Updater)
- **100Mbps+ CDN 전용 스트리밍 세션**: GitHub Release CDN 리다이렉트를 최우선 대역폭으로 수신 (`SparkleUpdaterManager`).
- **실시간 진행률 프로그레스바**: 다운로드 진행 현황을 `(15.4 MB / 48.2 MB - 32%)`와 같이 실시간 표출.

---

## 🛠️ 빌드 및 배포 스크립트 안내 (Build & Deployment)

프로젝트 루트의 자동화 빌드 스크립트를 통해 원클릭으로 실행 파일 및 설치 패키지를 생성할 수 있습니다:

### 1. 로컬 개발 및 앱 실행
```bash
./build.sh
```
모든 Swift 소스 컴파일, `xattr` 정리, ad-hoc 코드 서명 후 `MacOptimizationTool.app`을 실행합니다.

### 2. 웹 배포용 `.dmg` 디스크 이미지 패키징
```bash
./build_dmg.sh
```
드래그 앤 드롭 `/Applications` 설치 폴더가 포함된 `MacOptimizationTool_Setup.dmg` 이미지를 생성합니다.

### 3. GitHub Release 자동 게시
```bash
./release.sh v1.5.0 "릴리즈 노트 내용"
```
버전 커밋, Git 태그 생성, DMG 패키징, `gh release create`를 통해 GitHub Release 게시 및 DMG 첨부를 자동 진행합니다.

---

## 📁 프로젝트 디렉토리 구조 (Project Structure)

```
MacOptimizationTool/
├── Sources/                       # Swift 네이티브 소스 코드
│   ├── App.swift                  # AppDelegate, 메뉴바 아이콘 및 포그라운드 알림 연동
│   ├── MainView.swift             # 메인 레이아웃 및 서브 탭 라우팅
│   ├── PermissionManager.swift    # FDA (필수) & 알림 (선택) TCC 검사 엔진
│   ├── PermissionModalView.swift  # Glassmorphism 권한 안내 온보딩 모달
│   ├── DashboardView.swift        # 실시간 자원 대시보드 뷰
│   ├── UninstallerView.swift      # 앱 완전 삭제기 뷰 & 드롭존
│   ├── UninstallerViewModel.swift # 4단계 삭제 및 찌꺼기 추적 모델
│   ├── DiskCleanerView.swift      # 캐시 & 로그 디스크 정리기
│   ├── LargeFilesView.swift       # 대용량 방치 파일 검사기
│   ├── DuplicateView.swift        # 16-Worker 중복 파일 이진 해시 비교기
│   ├── PrivacyCleanerView.swift   # 브라우저 개인정보 수거기
│   ├── OldDownloadsView.swift     # 0.001초 방치 다운로드 분류기
│   ├── SettingsView.swift         # 스튜디오 통합 설정 뷰
│   ├── Theme.swift                # dynamicProvider 기반 디자인 토큰
│   ├── LanguageManager.swift      # 4개 국어 번역 관리자
│   ├── FileSafety.swift           # Pre-Auth 4단계 안전 삭제 엔진
│   └── SparkleUpdaterManager.swift# 초고속 CDN 인앱 업데이트 관리자
├── docs/                          # GitHub Pages Landing Website
│   ├── index.html                 # 모던 웹 디자인 사이트 (HTML/CSS/JS)
│   ├── screenshot_dashboard.jpg   # 대시보드 실제 구동 스크린샷
│   └── AppIcon.png                # 웹 브랜딩 아이콘 자산
├── AppIcon.icns                   # 1024x1024 멀티레이어 아이콘
├── build.sh                       # 기본 컴파일 & 서명 스크립트
├── build_dmg.sh                   # DMG 디스크 이미지 패키징 스크립트
├── release.sh                     # GitHub Release 자동화 스크립트
└── README.md                      # 프로젝트 공식 설명서
```

---

## 📄 라이선스 및 저작권 (License & Copyright)

**Copyright © 2026 Lab98 Studio. All rights reserved.**  
Designed & Engineered for macOS by Vincent Jeon @ Lab98 Studio.
