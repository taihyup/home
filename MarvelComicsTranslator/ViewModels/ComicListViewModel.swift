//
//  ComicListViewModel.swift
//  MarvelComicsTranslator
//
//  코믹 목록 화면의 ViewModel
//

import Foundation
import SwiftUI

@MainActor
class ComicListViewModel: ObservableObject {
    @Published var comics: [MarvelComic] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var searchText = ""

    private let apiService = MarvelAPIService.shared
    private var currentOffset = 0
    private let pageSize = 20
    private var hasMorePages = true

    // MARK: - 코믹 목록 로드

    /// 초기 코믹 목록 로드
    func loadComics() async {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil
        currentOffset = 0

        do {
            let fetchedComics = try await apiService.fetchComics(offset: 0, limit: pageSize)
            comics = fetchedComics
            hasMorePages = fetchedComics.count >= pageSize
            currentOffset = fetchedComics.count
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    /// 추가 코믹 로드 (페이지네이션)
    func loadMoreComicsIfNeeded(currentComic: MarvelComic) async {
        guard let lastComic = comics.last,
              currentComic.id == lastComic.id,
              hasMorePages,
              !isLoading else {
            return
        }

        isLoading = true

        do {
            let fetchedComics = try await apiService.fetchComics(offset: currentOffset, limit: pageSize)
            comics.append(contentsOf: fetchedComics)
            hasMorePages = fetchedComics.count >= pageSize
            currentOffset += fetchedComics.count
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    /// 코믹 검색
    func searchComics() async {
        guard !searchText.isEmpty else {
            await loadComics()
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let fetchedComics = try await apiService.searchComics(character: searchText)
            comics = fetchedComics
            hasMorePages = false  // 검색 결과는 페이지네이션 비활성화
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    /// 새로고침
    func refresh() async {
        if searchText.isEmpty {
            await loadComics()
        } else {
            await searchComics()
        }
    }
}
