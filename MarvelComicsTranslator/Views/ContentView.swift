//
//  ContentView.swift
//  MarvelComicsTranslator
//
//  메인 앱 화면 - 코믹 목록 표시
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ComicListViewModel()
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 검색바
                SearchBar(text: $viewModel.searchText, onSearch: {
                    Task {
                        await viewModel.searchComics()
                    }
                })
                .padding(.horizontal)
                .padding(.top, 8)

                // 코믹 그리드
                if viewModel.isLoading && viewModel.comics.isEmpty {
                    LoadingView()
                } else if let error = viewModel.errorMessage {
                    ErrorView(message: error) {
                        Task {
                            await viewModel.loadComics()
                        }
                    }
                } else if viewModel.comics.isEmpty {
                    EmptyStateView()
                } else {
                    ComicGridView(viewModel: viewModel)
                }
            }
            .navigationTitle("마블 코믹스")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showSettings = true }) {
                        Image(systemName: "gear")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .task {
                if viewModel.comics.isEmpty {
                    await viewModel.loadComics()
                }
            }
            .refreshable {
                await viewModel.refresh()
            }
        }
    }
}

// MARK: - 검색바

struct SearchBar: View {
    @Binding var text: String
    var onSearch: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)

            TextField("코믹 검색...", text: $text)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .onSubmit {
                    onSearch()
                }

            if !text.isEmpty {
                Button(action: {
                    text = ""
                    onSearch()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - 코믹 그리드

struct ComicGridView: View {
    @ObservedObject var viewModel: ComicListViewModel

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(viewModel.comics) { comic in
                    NavigationLink(destination: ComicReaderView(comic: comic)) {
                        ComicCardView(comic: comic)
                    }
                    .buttonStyle(.plain)
                    .onAppear {
                        Task {
                            await viewModel.loadMoreComicsIfNeeded(currentComic: comic)
                        }
                    }
                }
            }
            .padding()

            if viewModel.isLoading && !viewModel.comics.isEmpty {
                ProgressView()
                    .padding()
            }
        }
    }
}

// MARK: - 코믹 카드

struct ComicCardView: View {
    let comic: MarvelComic

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 썸네일 이미지
            AsyncImage(url: comic.thumbnailURL) { phase in
                switch phase {
                case .empty:
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .aspectRatio(0.65, contentMode: .fit)
                        .overlay {
                            ProgressView()
                        }
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(0.65, contentMode: .fit)
                case .failure:
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .aspectRatio(0.65, contentMode: .fit)
                        .overlay {
                            Image(systemName: "photo")
                                .foregroundColor(.gray)
                        }
                @unknown default:
                    EmptyView()
                }
            }
            .cornerRadius(8)
            .shadow(radius: 4)

            // 제목
            Text(comic.title)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(2)
                .foregroundColor(.primary)
        }
    }
}

// MARK: - 로딩 뷰

struct LoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("코믹 로딩 중...")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - 에러 뷰

struct ErrorView: View {
    let message: String
    var retryAction: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.orange)

            Text("오류 발생")
                .font(.headline)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("다시 시도") {
                retryAction()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - 빈 상태 뷰

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "book.closed")
                .font(.system(size: 50))
                .foregroundColor(.gray)

            Text("코믹이 없습니다")
                .font(.headline)
                .foregroundColor(.secondary)

            Text("검색어를 변경해 보세요")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - 설정 뷰

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("autoTranslate") private var autoTranslate = true
    @AppStorage("showOriginalText") private var showOriginalText = false

    var body: some View {
        NavigationStack {
            List {
                Section("번역 설정") {
                    Toggle("자동 번역", isOn: $autoTranslate)

                    Toggle("원문 함께 표시", isOn: $showOriginalText)
                }

                Section("번역 언어팩") {
                    NavigationLink(destination: LanguagePackView()) {
                        HStack {
                            Text("한국어 번역 언어팩")
                            Spacer()
                            if #available(iOS 17.4, *) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            } else {
                                Text("iOS 17.4 필요")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                }

                Section("앱 정보") {
                    HStack {
                        Text("버전")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }

                    Link(destination: URL(string: "https://developer.marvel.com")!) {
                        HStack {
                            Text("Marvel API 정보")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Section {
                    Text("이 앱은 Apple의 기본 번역 기능을 사용합니다. 별도의 비용이 발생하지 않으며, 오프라인에서도 사용 가능합니다.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("설정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("완료") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - 언어팩 뷰

struct LanguagePackView: View {
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Label("한국어 번역", systemImage: "globe.asia.australia.fill")
                        .font(.headline)

                    if #available(iOS 17.4, *) {
                        Text("iOS 17.4 이상에서 Apple 번역 기능을 사용할 수 있습니다.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        Text("이 기능을 사용하려면 iOS 17.4 이상이 필요합니다.")
                            .font(.subheadline)
                            .foregroundColor(.orange)
                    }
                }
                .padding(.vertical, 8)
            }

            Section("언어팩 다운로드 방법") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("1. 설정 앱을 엽니다")
                    Text("2. 일반 > 언어 및 지역으로 이동합니다")
                    Text("3. '번역 언어'를 탭합니다")
                    Text("4. 한국어를 다운로드합니다")
                }
                .font(.subheadline)
                .padding(.vertical, 8)

                Button("설정 앱 열기") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            }
        }
        .navigationTitle("번역 언어팩")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    ContentView()
}
