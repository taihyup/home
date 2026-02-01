//
//  TranslationModels.swift
//  MarvelComicsTranslator
//
//  번역 관련 데이터 모델
//

import Foundation
import CoreGraphics

// MARK: - 인식된 텍스트 블록

struct RecognizedTextBlock: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let boundingBox: CGRect  // 정규화된 좌표 (0-1 범위)
    let confidence: Float

    static func == (lhs: RecognizedTextBlock, rhs: RecognizedTextBlock) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - 번역된 텍스트 블록

struct TranslatedTextBlock: Identifiable, Equatable {
    let id = UUID()
    let originalText: String
    let translatedText: String
    let boundingBox: CGRect

    static func == (lhs: TranslatedTextBlock, rhs: TranslatedTextBlock) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - 번역 결과

struct TranslationResult: Identifiable {
    let id = UUID()
    let timestamp: Date
    let originalTexts: [String]
    let translatedTexts: [String]

    var combinedOriginal: String {
        originalTexts.joined(separator: "\n")
    }

    var combinedTranslation: String {
        translatedTexts.joined(separator: "\n")
    }
}

// MARK: - 앱 설정

struct AppSettings: Codable {
    var sourceLanguage: String = "en"
    var targetLanguage: String = "ko"
    var autoTranslate: Bool = true
    var showOriginalText: Bool = false
    var textToSpeech: Bool = false
    var processingInterval: Double = 1.0  // 초 단위

    static let `default` = AppSettings()
}
