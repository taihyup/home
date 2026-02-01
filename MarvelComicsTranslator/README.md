# 마블 코믹스 자동 번역 앱

Marvel Comics 앱에서 만화를 보면서 영어 텍스트를 실시간으로 한글 번역해주는 iOS 앱입니다.

## 작동 방식

```
[화면 기록 시작] → [Marvel Comics 앱에서 만화 보기]
                            ↓
              [실시간 화면 캡처 (Broadcast Extension)]
                            ↓
              [OCR 텍스트 인식 (Vision Framework)]
                            ↓
              [영어→한글 번역 (Apple Translation)]
                            ↓
              [PiP 창으로 번역 결과 표시]
```

## 주요 기능

- **실시간 화면 인식**: 화면 기록을 통해 Marvel Comics 앱 화면을 실시간 캡처
- **자동 텍스트 인식**: Apple Vision Framework로 영어 텍스트 OCR 인식
- **무료 번역**: Apple 기본 번역 기능 사용 (별도 비용 없음)
- **오프라인 지원**: 한국어 언어팩 다운로드 시 인터넷 없이 번역 가능
- **PiP 표시**: 다른 앱 사용 중에도 번역 결과를 작은 창으로 표시

## 시스템 요구사항

- iOS 17.4 이상 (Apple Translation Framework 지원)
- iPhone 또는 iPad

## 설치 및 설정

### 1. Xcode에서 빌드

1. Xcode 15 이상 필요
2. 프로젝트 열기
3. App Group 설정: `group.com.marvelcomics.translator`
4. 팀 서명 설정
5. iPhone/iPad에서 실행

### 2. 한국어 번역 언어팩 다운로드

1. 설정 앱 열기
2. 일반 > 언어 및 지역 > 번역 언어
3. 한국어 다운로드

## 프로젝트 구조

```
MarvelComicsTranslator/
├── MarvelComicsTranslatorApp.swift   # 앱 엔트리 포인트
├── Info.plist                         # 앱 설정
│
├── BroadcastExtension/                # 화면 기록 확장
│   ├── SampleHandler.swift            # 화면 프레임 처리
│   └── Info.plist
│
├── Models/
│   └── TranslationModels.swift        # 번역 데이터 모델
│
├── Services/
│   ├── ScreenCaptureService.swift     # 화면 캡처 관리
│   ├── TextRecognitionService.swift   # Vision OCR
│   ├── TranslationService.swift       # Apple Translation
│   ├── RealtimeTranslationService.swift # 실시간 번역 파이프라인
│   └── PiPService.swift               # Picture-in-Picture 관리
│
└── Views/
    └── ContentView.swift              # 메인 UI
```

## 사용 방법

1. **앱 실행** → "번역 시작" 버튼 탭
2. **화면 기록 선택** → "마블 번역" 선택 후 "브로드캐스트 시작"
3. **Marvel Comics 앱으로 이동** → 만화 보기
4. **자동 번역** → 화면의 영어 텍스트가 실시간으로 번역됨
5. **번역 확인** → PiP 창 또는 앱으로 돌아와서 확인
6. **종료** → 제어센터에서 화면 기록 중지

## 기술 스택

| 기술 | 용도 |
|------|------|
| SwiftUI | UI 프레임워크 |
| ReplayKit | 화면 기록 (Broadcast Extension) |
| Vision Framework | OCR 텍스트 인식 |
| Translation Framework | 영어→한글 번역 (iOS 17.4+) |
| AVKit | Picture-in-Picture |

## 주의사항

- 화면 기록 중에는 배터리 소모가 증가할 수 있습니다
- 번역 품질은 Apple 번역 엔진에 의존합니다
- 만화 특유의 폰트나 효과음은 인식률이 낮을 수 있습니다
- 앱 사용 시 Marvel Comics 구독이 필요합니다

## 라이선스

이 프로젝트는 교육 목적으로 제작되었습니다.
Marvel 콘텐츠의 저작권은 Marvel Entertainment에 있습니다.
