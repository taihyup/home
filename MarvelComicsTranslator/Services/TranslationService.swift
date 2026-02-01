//
//  TranslationService.swift
//  MarvelComicsTranslator
//
//  Apple Translation Framework를 사용한 번역 서비스
//  iOS 17.4+ 필요 (무료, 오프라인 지원)
//

import Foundation
import Translation

@available(iOS 17.4, *)
class TranslationService: ObservableObject {
    static let shared = TranslationService()

    @Published var isTranslationAvailable = false
    @Published var isDownloadingLanguage = false
    @Published var downloadProgress: Double = 0

    private var translationSession: TranslationSession?

    // 소스 언어: 영어, 타겟 언어: 한국어
    private let sourceLanguage = Locale.Language(identifier: "en")
    private let targetLanguage = Locale.Language(identifier: "ko")

    private init() {
        Task {
            await checkTranslationAvailability()
        }
    }

    // MARK: - 번역 가용성 확인

    /// 번역 기능 사용 가능 여부 확인
    func checkTranslationAvailability() async {
        let availability = LanguageAvailability()
        let status = await availability.status(
            from: sourceLanguage,
            to: targetLanguage
        )

        await MainActor.run {
            switch status {
            case .installed:
                isTranslationAvailable = true
            case .supported:
                // 언어팩 다운로드 필요
                isTranslationAvailable = false
            case .unsupported:
                isTranslationAvailable = false
            @unknown default:
                isTranslationAvailable = false
            }
        }
    }

    // MARK: - 언어팩 다운로드

    /// 한국어 번역 언어팩 다운로드 (필요한 경우)
    func downloadLanguageIfNeeded() async throws {
        let availability = LanguageAvailability()
        let status = await availability.status(
            from: sourceLanguage,
            to: targetLanguage
        )

        if status == .supported {
            await MainActor.run {
                isDownloadingLanguage = true
            }

            // 언어팩 다운로드는 시스템 설정에서 수동으로 해야 함
            // 설정 > 일반 > 언어 및 지역 > 번역 언어

            await MainActor.run {
                isDownloadingLanguage = false
            }
        }
    }

    // MARK: - 텍스트 번역

    /// 단일 텍스트 번역
    func translate(_ text: String) async throws -> String {
        guard !text.isEmpty else { return "" }

        let configuration = TranslationSession.Configuration(
            source: sourceLanguage,
            target: targetLanguage
        )

        let session = TranslationSession(configuration: configuration)

        do {
            let response = try await session.translate(text)
            return response.targetText
        } catch {
            throw TranslationError.translationFailed(error.localizedDescription)
        }
    }

    /// 여러 텍스트 일괄 번역 (효율적)
    func translateBatch(_ texts: [String]) async throws -> [String] {
        guard !texts.isEmpty else { return [] }

        let configuration = TranslationSession.Configuration(
            source: sourceLanguage,
            target: targetLanguage
        )

        let session = TranslationSession(configuration: configuration)

        do {
            let requests = texts.map { TranslationSession.Request(sourceText: $0) }
            let responses = try await session.translations(from: requests)
            return responses.map { $0.targetText }
        } catch {
            throw TranslationError.translationFailed(error.localizedDescription)
        }
    }

    /// 인식된 텍스트 블록들을 번역
    func translateTextBlocks(_ blocks: [RecognizedTextBlock]) async throws -> [TranslatedTextBlock] {
        let texts = blocks.map { $0.text }
        let translatedTexts = try await translateBatch(texts)

        var translatedBlocks: [TranslatedTextBlock] = []

        for (index, block) in blocks.enumerated() {
            let translatedBlock = TranslatedTextBlock(
                originalText: block.text,
                translatedText: translatedTexts[index],
                boundingBox: block.boundingBox
            )
            translatedBlocks.append(translatedBlock)
        }

        return translatedBlocks
    }
}

// MARK: - Translation Errors

enum TranslationError: Error, LocalizedError {
    case translationFailed(String)
    case languageNotAvailable
    case downloadRequired

    var errorDescription: String? {
        switch self {
        case .translationFailed(let message):
            return "번역 실패: \(message)"
        case .languageNotAvailable:
            return "번역 언어를 사용할 수 없습니다"
        case .downloadRequired:
            return "언어팩 다운로드가 필요합니다. 설정 > 일반 > 언어 및 지역 > 번역 언어에서 한국어를 다운로드해주세요."
        }
    }
}

// MARK: - iOS 17.4 미만 버전을 위한 Fallback

class TranslationServiceFallback: ObservableObject {
    static let shared = TranslationServiceFallback()

    /// iOS 17.4 미만에서는 기본 번역 앱을 열도록 안내
    func openTranslationSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}
