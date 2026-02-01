//
//  Comic.swift
//  MarvelComicsTranslator
//
//  마블 코믹 데이터 모델
//

import Foundation

// MARK: - Marvel API Response Models

struct MarvelAPIResponse: Codable {
    let code: Int
    let status: String
    let data: MarvelDataContainer
}

struct MarvelDataContainer: Codable {
    let offset: Int
    let limit: Int
    let total: Int
    let count: Int
    let results: [MarvelComic]
}

struct MarvelComic: Codable, Identifiable {
    let id: Int
    let title: String
    let description: String?
    let pageCount: Int
    let thumbnail: MarvelImage
    let images: [MarvelImage]
    let urls: [MarvelURL]?

    var thumbnailURL: URL? {
        thumbnail.fullURL
    }

    var allImageURLs: [URL] {
        images.compactMap { $0.fullURL }
    }
}

struct MarvelImage: Codable {
    let path: String
    let `extension`: String

    var fullURL: URL? {
        // Marvel API는 HTTPS를 사용해야 함
        let securedPath = path.replacingOccurrences(of: "http://", with: "https://")
        return URL(string: "\(securedPath).\(`extension`)")
    }
}

struct MarvelURL: Codable {
    let type: String
    let url: String
}

// MARK: - App Internal Models

struct ComicPage: Identifiable {
    let id = UUID()
    let imageURL: URL
    var image: Data?
    var recognizedTexts: [RecognizedTextBlock] = []
    var translatedTexts: [TranslatedTextBlock] = []
    var isTranslated: Bool = false
}

struct RecognizedTextBlock: Identifiable {
    let id = UUID()
    let text: String
    let boundingBox: CGRect  // 정규화된 좌표 (0-1 범위)
    let confidence: Float
}

struct TranslatedTextBlock: Identifiable {
    let id = UUID()
    let originalText: String
    let translatedText: String
    let boundingBox: CGRect
}
