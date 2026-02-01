//
//  RealtimeTranslationService.swift
//  MarvelComicsTranslator
//
//  실시간 번역 처리 서비스
//  화면 캡처 → OCR → 번역 파이프라인 관리
//

import Foundation
import UIKit
import Combine
import Vision

@MainActor
class RealtimeTranslationService: ObservableObject {
    static let shared = RealtimeTranslationService()

    // MARK: - Published Properties

    @Published var isProcessing = false
    @Published var currentTranslation: TranslationResult?
    @Published var translationHistory: [TranslationResult] = []
    @Published var errorMessage: String?

    // 최근 번역 텍스트 (PiP에 표시)
    @Published var displayText: String = ""
    @Published var originalText: String = ""

    // MARK: - Private Properties

    private let screenCaptureService = ScreenCaptureService.shared
    private let textRecognitionService = TextRecognitionService.shared
    private var cancellables = Set<AnyCancellable>()
    private var lastProcessedImage: UIImage?
    private var isCurrentlyProcessing = false

    // 중복 번역 방지를 위한 캐시
    private var translationCache: [String: String] = [:]
    private let maxCacheSize = 100

    private init() {
        setupBindings()
    }

    // MARK: - Public Methods

    /// 실시간 번역 시작
    func startRealtimeTranslation() {
        screenCaptureService.startMonitoring()
    }

    /// 실시간 번역 중지
    func stopRealtimeTranslation() {
        screenCaptureService.stopMonitoring()
        isProcessing = false
    }

    /// 현재 프레임 수동 번역
    func translateCurrentFrame() async {
        guard let frame = screenCaptureService.currentFrame else {
            errorMessage = "캡처된 화면이 없습니다"
            return
        }

        await processFrame(frame)
    }

    /// 번역 기록 초기화
    func clearHistory() {
        translationHistory.removeAll()
        translationCache.removeAll()
    }

    // MARK: - Private Methods

    private func setupBindings() {
        // 새 프레임이 캡처되면 자동으로 처리
        screenCaptureService.$currentFrame
            .compactMap { $0 }
            .removeDuplicates { prev, next in
                // 이미지가 동일하면 처리하지 않음
                prev.pngData() == next.pngData()
            }
            .sink { [weak self] frame in
                Task { @MainActor in
                    await self?.processFrame(frame)
                }
            }
            .store(in: &cancellables)
    }

    private func processFrame(_ image: UIImage) async {
        // 이미 처리 중이면 스킵
        guard !isCurrentlyProcessing else { return }

        isCurrentlyProcessing = true
        isProcessing = true

        defer {
            isCurrentlyProcessing = false
            isProcessing = false
        }

        do {
            // 1. OCR 텍스트 인식
            guard let cgImage = image.cgImage else {
                throw ProcessingError.invalidImage
            }

            let recognizedBlocks = try await textRecognitionService.recognizeText(from: cgImage)

            guard !recognizedBlocks.isEmpty else {
                // 텍스트가 없으면 표시 초기화
                displayText = ""
                originalText = ""
                return
            }

            // 2. 텍스트 추출 및 중복 확인
            let combinedText = recognizedBlocks.map { $0.text }.joined(separator: " ")

            // 이전과 동일한 텍스트면 캐시된 번역 사용
            if let cachedTranslation = translationCache[combinedText] {
                displayText = cachedTranslation
                originalText = combinedText
                return
            }

            // 3. 번역 수행
            if #available(iOS 17.4, *) {
                let translationService = TranslationService.shared
                let translatedBlocks = try await translationService.translateTextBlocks(recognizedBlocks)

                let translatedText = translatedBlocks.map { $0.translatedText }.joined(separator: " ")

                // 캐시에 저장
                cacheTranslation(original: combinedText, translated: translatedText)

                // 결과 저장
                let result = TranslationResult(
                    timestamp: Date(),
                    originalTexts: recognizedBlocks.map { $0.text },
                    translatedTexts: translatedBlocks.map { $0.translatedText }
                )

                displayText = translatedText
                originalText = combinedText
                currentTranslation = result

                // 히스토리에 추가 (최대 50개)
                translationHistory.insert(result, at: 0)
                if translationHistory.count > 50 {
                    translationHistory.removeLast()
                }

            } else {
                // iOS 17.4 미만
                displayText = combinedText
                originalText = combinedText
                errorMessage = "iOS 17.4 이상이 필요합니다"
            }

        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func cacheTranslation(original: String, translated: String) {
        // 캐시 크기 제한
        if translationCache.count >= maxCacheSize {
            translationCache.removeAll()
        }
        translationCache[original] = translated
    }
}

// MARK: - Processing Errors

enum ProcessingError: Error, LocalizedError {
    case invalidImage
    case noTextFound
    case processingFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "이미지를 처리할 수 없습니다"
        case .noTextFound:
            return "텍스트를 찾을 수 없습니다"
        case .processingFailed(let message):
            return "처리 실패: \(message)"
        }
    }
}
