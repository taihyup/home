//
//  MarvelAPIService.swift
//  MarvelComicsTranslator
//
//  마블 API 서비스
//  Marvel Developer Portal에서 API 키 발급 필요: https://developer.marvel.com
//

import Foundation
import CryptoKit

class MarvelAPIService: ObservableObject {
    static let shared = MarvelAPIService()

    // TODO: Marvel Developer Portal에서 발급받은 키로 교체
    // https://developer.marvel.com 에서 무료로 발급 가능
    private let publicKey = "YOUR_PUBLIC_KEY"
    private let privateKey = "YOUR_PRIVATE_KEY"
    private let baseURL = "https://gateway.marvel.com/v1/public"

    private init() {}

    // MARK: - MD5 Hash 생성 (Marvel API 인증에 필요)

    private func md5Hash(_ string: String) -> String {
        let digest = Insecure.MD5.hash(data: Data(string.utf8))
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }

    private func authParameters() -> String {
        let timestamp = String(Int(Date().timeIntervalSince1970))
        let hash = md5Hash("\(timestamp)\(privateKey)\(publicKey)")
        return "ts=\(timestamp)&apikey=\(publicKey)&hash=\(hash)"
    }

    // MARK: - API Calls

    /// 코믹 목록 가져오기
    func fetchComics(offset: Int = 0, limit: Int = 20) async throws -> [MarvelComic] {
        let urlString = "\(baseURL)/comics?\(authParameters())&offset=\(offset)&limit=\(limit)&orderBy=-onsaleDate&format=comic"

        guard let url = URL(string: urlString) else {
            throw MarvelAPIError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw MarvelAPIError.invalidResponse
        }

        let decoder = JSONDecoder()
        let apiResponse = try decoder.decode(MarvelAPIResponse.self, from: data)

        return apiResponse.data.results
    }

    /// 특정 코믹 상세 정보 가져오기
    func fetchComic(id: Int) async throws -> MarvelComic {
        let urlString = "\(baseURL)/comics/\(id)?\(authParameters())"

        guard let url = URL(string: urlString) else {
            throw MarvelAPIError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw MarvelAPIError.invalidResponse
        }

        let decoder = JSONDecoder()
        let apiResponse = try decoder.decode(MarvelAPIResponse.self, from: data)

        guard let comic = apiResponse.data.results.first else {
            throw MarvelAPIError.comicNotFound
        }

        return comic
    }

    /// 캐릭터로 코믹 검색
    func searchComics(character: String, offset: Int = 0, limit: Int = 20) async throws -> [MarvelComic] {
        guard let encodedCharacter = character.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            throw MarvelAPIError.invalidURL
        }

        let urlString = "\(baseURL)/comics?\(authParameters())&titleStartsWith=\(encodedCharacter)&offset=\(offset)&limit=\(limit)"

        guard let url = URL(string: urlString) else {
            throw MarvelAPIError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw MarvelAPIError.invalidResponse
        }

        let decoder = JSONDecoder()
        let apiResponse = try decoder.decode(MarvelAPIResponse.self, from: data)

        return apiResponse.data.results
    }

    /// 이미지 다운로드
    func downloadImage(from url: URL) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw MarvelAPIError.imageDownloadFailed
        }

        return data
    }
}

// MARK: - Errors

enum MarvelAPIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case comicNotFound
    case imageDownloadFailed
    case decodingError

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "잘못된 URL입니다"
        case .invalidResponse:
            return "서버 응답이 올바르지 않습니다"
        case .comicNotFound:
            return "코믹을 찾을 수 없습니다"
        case .imageDownloadFailed:
            return "이미지 다운로드에 실패했습니다"
        case .decodingError:
            return "데이터 파싱에 실패했습니다"
        }
    }
}
