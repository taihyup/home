//
//  ContentView.swift
//  MarvelComicsTranslator
//
//  메인 화면 - 화면 기록 시작/중지, 번역 상태 표시
//

import SwiftUI
import ReplayKit

struct ContentView: View {
    @StateObject private var screenCaptureService = ScreenCaptureService.shared
    @StateObject private var translationService = RealtimeTranslationService.shared
    @StateObject private var pipService = PiPService.shared

    @State private var showSettings = false
    @State private var showHistory = false

    var body: some View {
        NavigationStack {
            ZStack {
                // 배경 그라데이션
                LinearGradient(
                    colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 24) {
                    // 헤더
                    headerSection

                    // 상태 카드
                    statusCard

                    // 번역 결과 미리보기
                    if !translationService.displayText.isEmpty {
                        translationPreviewCard
                    }

                    Spacer()

                    // 브로드캐스트 시작 버튼
                    broadcastButton

                    // 안내 텍스트
                    instructionText
                }
                .padding()
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack {
                        Button(action: { showHistory = true }) {
                            Image(systemName: "clock.arrow.circlepath")
                        }

                        Button(action: { showSettings = true }) {
                            Image(systemName: "gearshape")
                        }
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showHistory) {
                TranslationHistoryView()
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "character.bubble.fill")
                .font(.system(size: 60))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text("마블 코믹스 번역기")
                .font(.title)
                .fontWeight(.bold)

            Text("만화를 보면서 실시간 한글 번역")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.top, 20)
    }

    // MARK: - Status Card

    private var statusCard: some View {
        VStack(spacing: 16) {
            HStack {
                statusIndicator(
                    title: "화면 기록",
                    isActive: screenCaptureService.isBroadcasting,
                    activeIcon: "record.circle.fill",
                    inactiveIcon: "record.circle"
                )

                Divider()
                    .frame(height: 40)

                statusIndicator(
                    title: "번역 처리",
                    isActive: translationService.isProcessing,
                    activeIcon: "arrow.triangle.2.circlepath.circle.fill",
                    inactiveIcon: "arrow.triangle.2.circlepath.circle"
                )

                Divider()
                    .frame(height: 40)

                statusIndicator(
                    title: "PiP",
                    isActive: pipService.isPiPActive,
                    activeIcon: "pip.fill",
                    inactiveIcon: "pip"
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }

    private func statusIndicator(title: String, isActive: Bool, activeIcon: String, inactiveIcon: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: isActive ? activeIcon : inactiveIcon)
                .font(.title2)
                .foregroundColor(isActive ? .green : .gray)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Translation Preview Card

    private var translationPreviewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "text.bubble.fill")
                    .foregroundColor(.blue)
                Text("최근 번역")
                    .font(.headline)
                Spacer()
            }

            Text(translationService.displayText)
                .font(.body)
                .foregroundColor(.primary)
                .lineLimit(4)

            if !translationService.originalText.isEmpty {
                Divider()

                Text(translationService.originalText)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }

    // MARK: - Broadcast Button

    private var broadcastButton: some View {
        VStack(spacing: 12) {
            if screenCaptureService.isBroadcasting {
                // 중지 버튼
                Button(action: stopBroadcast) {
                    HStack {
                        Image(systemName: "stop.circle.fill")
                            .font(.title2)
                        Text("번역 중지")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .cornerRadius(16)
                }
            } else {
                // 시작 버튼 - RPSystemBroadcastPickerView 사용
                BroadcastPickerRepresentable()
                    .frame(height: 56)
                    .cornerRadius(16)
            }
        }
    }

    // MARK: - Instruction Text

    private var instructionText: some View {
        VStack(spacing: 8) {
            if !screenCaptureService.isBroadcasting {
                Text("사용 방법:")
                    .font(.caption)
                    .fontWeight(.semibold)

                VStack(alignment: .leading, spacing: 4) {
                    instructionRow(number: "1", text: "위 버튼을 눌러 화면 기록 시작")
                    instructionRow(number: "2", text: "Marvel Comics 앱으로 이동")
                    instructionRow(number: "3", text: "만화를 보면 자동으로 번역됩니다")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            } else {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("화면을 분석하고 번역하는 중...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.bottom, 20)
    }

    private func instructionRow(number: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(number)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 18, height: 18)
                .background(Circle().fill(Color.blue))

            Text(text)
        }
    }

    // MARK: - Actions

    private func stopBroadcast() {
        translationService.stopRealtimeTranslation()
        pipService.stopPiP()
    }
}

// MARK: - Broadcast Picker (시스템 화면 기록 UI)

struct BroadcastPickerRepresentable: UIViewRepresentable {
    func makeUIView(context: Context) -> RPSystemBroadcastPickerView {
        let picker = RPSystemBroadcastPickerView(frame: CGRect(x: 0, y: 0, width: 200, height: 56))

        // 브로드캐스트 확장 번들 ID 설정
        picker.preferredExtension = "com.marvelcomics.translator.BroadcastExtension"

        // 버튼 스타일 커스터마이즈
        picker.showsMicrophoneButton = false

        // 버튼 찾아서 스타일 변경
        for subview in picker.subviews {
            if let button = subview as? UIButton {
                button.setTitle("  번역 시작", for: .normal)
                button.setTitleColor(.white, for: .normal)
                button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 17)
                button.backgroundColor = UIColor.systemBlue
                button.layer.cornerRadius = 16
                button.setImage(UIImage(systemName: "play.circle.fill"), for: .normal)
                button.tintColor = .white
            }
        }

        return picker
    }

    func updateUIView(_ uiView: RPSystemBroadcastPickerView, context: Context) {}
}

// MARK: - Settings View

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("showOriginalText") private var showOriginalText = false
    @AppStorage("textToSpeech") private var textToSpeech = false
    @AppStorage("processingInterval") private var processingInterval = 1.0

    var body: some View {
        NavigationStack {
            Form {
                Section("번역 설정") {
                    Toggle("원문 함께 표시", isOn: $showOriginalText)

                    Toggle("음성으로 읽어주기 (TTS)", isOn: $textToSpeech)

                    VStack(alignment: .leading) {
                        Text("처리 간격: \(String(format: "%.1f", processingInterval))초")
                        Slider(value: $processingInterval, in: 0.5...3.0, step: 0.5)
                    }
                }

                Section("언어 설정") {
                    HStack {
                        Text("원본 언어")
                        Spacer()
                        Text("영어 (English)")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("번역 언어")
                        Spacer()
                        Text("한국어")
                            .foregroundColor(.secondary)
                    }

                    NavigationLink(destination: LanguagePackView()) {
                        Text("번역 언어팩 설정")
                    }
                }

                Section("정보") {
                    HStack {
                        Text("버전")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
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

// MARK: - Language Pack View

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

// MARK: - Translation History View

struct TranslationHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var translationService = RealtimeTranslationService.shared

    var body: some View {
        NavigationStack {
            List {
                if translationService.translationHistory.isEmpty {
                    ContentUnavailableView(
                        "번역 기록 없음",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("화면 기록을 시작하면 번역 기록이 여기에 표시됩니다")
                    )
                } else {
                    ForEach(translationService.translationHistory) { result in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(result.combinedTranslation)
                                .font(.body)

                            Text(result.combinedOriginal)
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Text(result.timestamp, style: .time)
                                .font(.caption2)
                                .foregroundColor(.tertiary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("번역 기록")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !translationService.translationHistory.isEmpty {
                        Button("모두 삭제", role: .destructive) {
                            translationService.clearHistory()
                        }
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("완료") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
