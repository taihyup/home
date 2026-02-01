# 마블 코믹스 자동 번역 앱

마블 코믹스를 읽을 때 영어 텍스트를 자동으로 한글로 번역해주는 iOS 앱입니다.

## 주요 기능

- **자동 텍스트 인식**: Apple Vision Framework를 사용하여 만화 이미지에서 영어 텍스트를 자동으로 인식
- **실시간 번역**: Apple Translation Framework를 사용하여 영어를 한글로 번역
- **무료 번역**: iOS 기본 번역 기능을 사용하므로 별도 비용 없음
- **오프라인 지원**: 한국어 언어팩을 다운로드하면 오프라인에서도 번역 가능
- **번역 오버레이**: 원본 이미지 위에 번역된 텍스트를 말풍선 형태로 표시

## 시스템 요구사항

- iOS 17.4 이상 (Apple Translation Framework 지원)
- iPhone 또는 iPad

## 설치 및 설정

### 1. Marvel API 키 발급

1. [Marvel Developer Portal](https://developer.marvel.com)에 가입
2. API 키 발급 (무료)
3. `Services/MarvelAPIService.swift` 파일에서 키 설정:

```swift
private let publicKey = "YOUR_PUBLIC_KEY"
private let privateKey = "YOUR_PRIVATE_KEY"
```

### 2. 한국어 번역 언어팩 다운로드

1. 설정 앱 열기
2. 일반 > 언어 및 지역 > 번역 언어
3. 한국어 다운로드

### 3. Xcode에서 빌드

1. Xcode 15 이상 필요
2. 프로젝트 열기
3. 팀 서명 설정
4. iPhone/iPad에서 실행

## 프로젝트 구조

```
MarvelComicsTranslator/
├── MarvelComicsTranslatorApp.swift  # 앱 엔트리 포인트
├── Info.plist                        # 앱 설정
│
├── Models/
│   └── Comic.swift                   # 마블 코믹 데이터 모델
│
├── Services/
│   ├── MarvelAPIService.swift        # Marvel API 연동
│   ├── TranslationService.swift      # Apple Translation 서비스
│   └── TextRecognitionService.swift  # Vision OCR 서비스
│
├── Views/
│   ├── ContentView.swift             # 메인 화면 (코믹 목록)
│   └── ComicReaderView.swift         # 코믹 리더 화면
│
└── ViewModels/
    ├── ComicListViewModel.swift      # 코믹 목록 ViewModel
    └── ComicReaderViewModel.swift    # 코믹 리더 ViewModel
```

## 사용 방법

1. 앱 실행 후 코믹 목록에서 원하는 만화 선택
2. 코믹 리더에서 이미지가 로드되면 자동으로 텍스트 인식 및 번역 시작
3. 번역된 텍스트가 원본 이미지 위에 오버레이로 표시됨
4. 우측 상단의 말풍선 아이콘으로 번역 표시/숨김 토글
5. 좌우 스와이프로 페이지 이동

## 기술 스택

- **SwiftUI**: UI 프레임워크
- **Apple Vision Framework**: OCR 텍스트 인식
- **Apple Translation Framework**: 영어→한글 번역 (iOS 17.4+)
- **Marvel API**: 코믹 데이터 및 이미지

## 주의사항

- Marvel API는 개인/비상업적 용도로만 무료 사용 가능
- 번역 품질은 Apple 번역 엔진에 의존
- 만화 특유의 폰트나 효과음은 인식률이 낮을 수 있음

## 라이선스

이 프로젝트는 교육 목적으로 제작되었습니다.
Marvel 콘텐츠의 저작권은 Marvel Entertainment에 있습니다.
