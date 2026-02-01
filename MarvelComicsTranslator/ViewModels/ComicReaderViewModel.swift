//
//  ComicReaderViewModel.swift
//  MarvelComicsTranslator
//
//  코믹 리더 화면의 ViewModel
//  텍스트 인식 및 번역 처리
//

import Foundation
import SwiftUI
import Vision

@MainActor
class ComicReaderViewModel: ObservableObject {
    @Published var comic: MarvelComic
    @Published var pages: [ComicPage] = []
    @Published var currentPageIndex = 0
    @Published var isLoading = false
    @Published var isTranslating = false
    @Published var showTranslation = true
    @Published var errorMessage: String?
    @Published var translationProgress: Double = 0

    private let apiService = MarvelAPIService.shared
    private let textRecognitionService = TextRecognitionService.shared

    init(comic: MarvelComic) {
        self.comic = comic
        setupPages()
    }

    // MARK: - 페이지 설정

    private func setupPages() {
        // 코믹의 모든 이미지 URL로 페이지 생성
        var allURLs = comic.allImageURLs

        // 이미지가 없으면 썸네일 사용
        if allURLs.isEmpty, let thumbnailURL = comic.thumbnailURL {
            allURLs = [thumbnailURL]
        }

        pages = allURLs.map { ComicPage(imageURL: $0) }
    }

    // MARK: - 이미지 로드

    /// 현재 페이지 이미지 로드
    func loadCurrentPageImage() async {
        guard currentPageIndex < pages.count else { return }
        guard pages[currentPageIndex].image == nil else { return }

        isLoading = true

        do {
            let imageData = try await apiService.downloadImage(from: pages[currentPageIndex].imageURL)
            pages[currentPageIndex].image = imageData

            // 이미지 로드 후 자동으로 텍스트 인식 및 번역 시작
            await recognizeAndTranslateCurrentPage()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    /// 모든 페이지 이미지 미리 로드
    func preloadAllPages() async {
        for index in pages.indices {
            guard pages[index].image == nil else { continue }

            do {
                let imageData = try await apiService.downloadImage(from: pages[index].imageURL)
                pages[index].image = imageData
            } catch {
                // 개별 페이지 로드 실패는 무시
                continue
            }
        }
    }

    // MARK: - 텍스트 인식 및 번역

    /// 현재 페이지 텍스트 인식 및 번역
    func recognizeAndTranslateCurrentPage() async {
        guard currentPageIndex < pages.count else { return }
        guard let imageData = pages[currentPageIndex].image else { return }
        guard !pages[currentPageIndex].isTranslated else { return }

        isTranslating = true
        translationProgress = 0

        do {
            // 1. 텍스트 인식
            translationProgress = 0.3
            let recognizedBlocks = try await textRecognitionService.recognizeText(from: imageData)
            pages[currentPageIndex].recognizedTexts = recognizedBlocks

            // 2. 번역
            translationProgress = 0.6
            if #available(iOS 17.4, *) {
                let translationService = TranslationService.shared
                let translatedBlocks = try await translationService.translateTextBlocks(recognizedBlocks)
                pages[currentPageIndex].translatedTexts = translatedBlocks
            } else {
                // iOS 17.4 미만: 번역 없이 원본 텍스트만 표시
                pages[currentPageIndex].translatedTexts = recognizedBlocks.map { block in
                    TranslatedTextBlock(
                        originalText: block.text,
                        translatedText: block.text,  // 원본 유지
                        boundingBox: block.boundingBox
                    )
                }
            }

            translationProgress = 1.0
            pages[currentPageIndex].isTranslated = true
        } catch {
            errorMessage = error.localizedDescription
        }

        isTranslating = false
    }

    /// 특정 페이지 텍스트 인식 및 번역
    func recognizeAndTranslatePage(at index: Int) async {
        guard index < pages.count else { return }

        // 이미지가 없으면 먼저 로드
        if pages[index].image == nil {
            do {
                let imageData = try await apiService.downloadImage(from: pages[index].imageURL)
                pages[index].image = imageData
            } catch {
                return
            }
        }

        guard let imageData = pages[index].image else { return }
        guard !pages[index].isTranslated else { return }

        do {
            let recognizedBlocks = try await textRecognitionService.recognizeText(from: imageData)
            pages[index].recognizedTexts = recognizedBlocks

            if #available(iOS 17.4, *) {
                let translationService = TranslationService.shared
                let translatedBlocks = try await translationService.translateTextBlocks(recognizedBlocks)
                pages[index].translatedTexts = translatedBlocks
            }

            pages[index].isTranslated = true
        } catch {
            // 에러 무시
        }
    }

    // MARK: - 페이지 네비게이션

    var currentPage: ComicPage? {
        guard currentPageIndex < pages.count else { return nil }
        return pages[currentPageIndex]
    }

    var hasNextPage: Bool {
        currentPageIndex < pages.count - 1
    }

    var hasPreviousPage: Bool {
        currentPageIndex > 0
    }

    func goToNextPage() {
        guard hasNextPage else { return }
        currentPageIndex += 1
        Task {
            await loadCurrentPageImage()
        }
    }

    func goToPreviousPage() {
        guard hasPreviousPage else { return }
        currentPageIndex -= 1
        Task {
            await loadCurrentPageImage()
        }
    }

    func goToPage(_ index: Int) {
        guard index >= 0, index < pages.count else { return }
        currentPageIndex = index
        Task {
            await loadCurrentPageImage()
        }
    }

    // MARK: - 번역 토글

    func toggleTranslation() {
        showTranslation.toggle()
    }

    /// 현재 페이지 번역 재시도
    func retryTranslation() async {
        guard currentPageIndex < pages.count else { return }
        pages[currentPageIndex].isTranslated = false
        pages[currentPageIndex].recognizedTexts = []
        pages[currentPageIndex].translatedTexts = []
        await recognizeAndTranslateCurrentPage()
    }
}
