//
//  ComicReaderView.swift
//  MarvelComicsTranslator
//
//  코믹 리더 화면 - 만화 이미지와 번역 오버레이 표시
//

import SwiftUI

struct ComicReaderView: View {
    @StateObject private var viewModel: ComicReaderViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showControls = true
    @State private var showPageSelector = false

    init(comic: MarvelComic) {
        _viewModel = StateObject(wrappedValue: ComicReaderViewModel(comic: comic))
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 배경
                Color.black.ignoresSafeArea()

                // 메인 컨텐츠
                if let page = viewModel.currentPage {
                    ComicPageView(
                        page: page,
                        showTranslation: viewModel.showTranslation,
                        geometry: geometry
                    )
                    .gesture(
                        DragGesture(minimumDistance: 50)
                            .onEnded { value in
                                if value.translation.width < -50 {
                                    viewModel.goToNextPage()
                                } else if value.translation.width > 50 {
                                    viewModel.goToPreviousPage()
                                }
                            }
                    )
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showControls.toggle()
                        }
                    }
                }

                // 로딩 인디케이터
                if viewModel.isLoading {
                    LoadingOverlay()
                }

                // 번역 진행 상태
                if viewModel.isTranslating {
                    TranslationProgressOverlay(progress: viewModel.translationProgress)
                }

                // 컨트롤 UI
                if showControls {
                    ControlOverlay(
                        viewModel: viewModel,
                        showPageSelector: $showPageSelector,
                        dismiss: { dismiss() }
                    )
                }
            }
        }
        .navigationBarHidden(true)
        .statusBar(hidden: !showControls)
        .sheet(isPresented: $showPageSelector) {
            PageSelectorView(viewModel: viewModel)
        }
        .task {
            await viewModel.loadCurrentPageImage()
        }
        .alert("오류", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("확인") {
                viewModel.errorMessage = nil
            }
            Button("다시 시도") {
                Task {
                    await viewModel.retryTranslation()
                }
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
}

// MARK: - 코믹 페이지 뷰

struct ComicPageView: View {
    let page: ComicPage
    let showTranslation: Bool
    let geometry: GeometryProxy

    var body: some View {
        ZStack {
            // 원본 이미지
            if let imageData = page.image,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: geometry.size.width, maxHeight: geometry.size.height)

                // 번역 오버레이
                if showTranslation && page.isTranslated {
                    TranslationOverlayView(
                        translatedTexts: page.translatedTexts,
                        imageSize: CGSize(
                            width: min(geometry.size.width, geometry.size.height * (uiImage.size.width / uiImage.size.height)),
                            height: min(geometry.size.height, geometry.size.width * (uiImage.size.height / uiImage.size.width))
                        )
                    )
                }
            } else {
                // 이미지 로딩 중
                ProgressView()
                    .scaleEffect(1.5)
            }
        }
    }
}

// MARK: - 번역 오버레이 뷰

struct TranslationOverlayView: View {
    let translatedTexts: [TranslatedTextBlock]
    let imageSize: CGSize

    var body: some View {
        ZStack {
            ForEach(translatedTexts) { textBlock in
                TranslatedTextBubble(textBlock: textBlock, imageSize: imageSize)
            }
        }
        .frame(width: imageSize.width, height: imageSize.height)
    }
}

// MARK: - 번역된 텍스트 말풍선

struct TranslatedTextBubble: View {
    let textBlock: TranslatedTextBlock
    let imageSize: CGSize
    @AppStorage("showOriginalText") private var showOriginalText = false

    var body: some View {
        let rect = CGRect(
            x: textBlock.boundingBox.minX * imageSize.width,
            y: textBlock.boundingBox.minY * imageSize.height,
            width: textBlock.boundingBox.width * imageSize.width,
            height: textBlock.boundingBox.height * imageSize.height
        )

        VStack(spacing: 2) {
            // 번역된 텍스트
            Text(textBlock.translatedText)
                .font(.system(size: calculateFontSize(for: rect)))
                .fontWeight(.bold)
                .foregroundColor(.black)
                .multilineTextAlignment(.center)
                .lineLimit(nil)

            // 원본 텍스트 (옵션)
            if showOriginalText {
                Text(textBlock.originalText)
                    .font(.system(size: calculateFontSize(for: rect) * 0.7))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.white.opacity(0.95))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.black.opacity(0.3), lineWidth: 1)
        )
        .frame(width: max(rect.width, 60), height: max(rect.height, 20))
        .position(x: rect.midX, y: rect.midY)
    }

    private func calculateFontSize(for rect: CGRect) -> CGFloat {
        let baseSize: CGFloat = 12
        let scaleFactor = min(rect.width / 100, rect.height / 30)
        return max(8, min(baseSize * scaleFactor, 18))
    }
}

// MARK: - 로딩 오버레이

struct LoadingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.5)

            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)

                Text("이미지 로딩 중...")
                    .foregroundColor(.white)
            }
            .padding(24)
            .background(Color.black.opacity(0.7))
            .cornerRadius(12)
        }
        .ignoresSafeArea()
    }
}

// MARK: - 번역 진행 오버레이

struct TranslationProgressOverlay: View {
    let progress: Double

    var body: some View {
        VStack(spacing: 12) {
            ProgressView(value: progress, total: 1.0)
                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                .frame(width: 200)

            Text(progressText)
                .font(.caption)
                .foregroundColor(.white)
        }
        .padding(20)
        .background(Color.black.opacity(0.7))
        .cornerRadius(12)
    }

    private var progressText: String {
        if progress < 0.5 {
            return "텍스트 인식 중..."
        } else if progress < 1.0 {
            return "번역 중..."
        } else {
            return "완료!"
        }
    }
}

// MARK: - 컨트롤 오버레이

struct ControlOverlay: View {
    @ObservedObject var viewModel: ComicReaderViewModel
    @Binding var showPageSelector: Bool
    var dismiss: () -> Void

    var body: some View {
        VStack {
            // 상단 바
            HStack {
                Button(action: dismiss) {
                    Image(systemName: "xmark")
                        .font(.title2)
                        .foregroundColor(.white)
                        .padding(12)
                        .background(Circle().fill(Color.black.opacity(0.5)))
                }

                Spacer()

                Text(viewModel.comic.title)
                    .font(.headline)
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .padding(.horizontal)

                Spacer()

                // 번역 토글 버튼
                Button(action: {
                    viewModel.toggleTranslation()
                }) {
                    Image(systemName: viewModel.showTranslation ? "text.bubble.fill" : "text.bubble")
                        .font(.title2)
                        .foregroundColor(viewModel.showTranslation ? .blue : .white)
                        .padding(12)
                        .background(Circle().fill(Color.black.opacity(0.5)))
                }
            }
            .padding()
            .background(
                LinearGradient(
                    colors: [Color.black.opacity(0.7), Color.clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            Spacer()

            // 하단 바
            VStack(spacing: 16) {
                // 페이지 인디케이터
                Text("\(viewModel.currentPageIndex + 1) / \(viewModel.pages.count)")
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.black.opacity(0.5)))

                // 네비게이션 버튼
                HStack(spacing: 40) {
                    // 이전 페이지
                    Button(action: {
                        viewModel.goToPreviousPage()
                    }) {
                        Image(systemName: "chevron.left.circle.fill")
                            .font(.system(size: 44))
                            .foregroundColor(viewModel.hasPreviousPage ? .white : .gray.opacity(0.5))
                    }
                    .disabled(!viewModel.hasPreviousPage)

                    // 페이지 선택
                    Button(action: {
                        showPageSelector = true
                    }) {
                        Image(systemName: "square.grid.2x2.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Circle().fill(Color.black.opacity(0.5)))
                    }

                    // 다음 페이지
                    Button(action: {
                        viewModel.goToNextPage()
                    }) {
                        Image(systemName: "chevron.right.circle.fill")
                            .font(.system(size: 44))
                            .foregroundColor(viewModel.hasNextPage ? .white : .gray.opacity(0.5))
                    }
                    .disabled(!viewModel.hasNextPage)
                }
            }
            .padding()
            .background(
                LinearGradient(
                    colors: [Color.clear, Color.black.opacity(0.7)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
    }
}

// MARK: - 페이지 선택 뷰

struct PageSelectorView: View {
    @ObservedObject var viewModel: ComicReaderViewModel
    @Environment(\.dismiss) private var dismiss

    private let columns = [
        GridItem(.adaptive(minimum: 100), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(Array(viewModel.pages.enumerated()), id: \.element.id) { index, page in
                        PageThumbnail(
                            page: page,
                            index: index,
                            isSelected: index == viewModel.currentPageIndex
                        )
                        .onTapGesture {
                            viewModel.goToPage(index)
                            dismiss()
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("페이지 선택")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - 페이지 썸네일

struct PageThumbnail: View {
    let page: ComicPage
    let index: Int
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 4) {
            if let imageData = page.image,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 150)
                    .cornerRadius(8)
            } else {
                AsyncImage(url: page.imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 150)
                            .cornerRadius(8)
                    default:
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 150)
                            .cornerRadius(8)
                            .overlay {
                                ProgressView()
                            }
                    }
                }
            }

            Text("\(index + 1)")
                .font(.caption)
                .foregroundColor(isSelected ? .blue : .primary)
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 3)
        )
    }
}

#Preview {
    ComicReaderView(comic: MarvelComic(
        id: 1,
        title: "Amazing Spider-Man #1",
        description: "테스트 코믹",
        pageCount: 32,
        thumbnail: MarvelImage(path: "https://i.annihil.us/u/prod/marvel/i/mg/c/e0/535fecbbb9784", extension: "jpg"),
        images: [],
        urls: nil
    ))
}
