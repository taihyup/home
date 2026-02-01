//
//  ScreenCaptureService.swift
//  MarvelComicsTranslator
//
//  화면 캡처 관리 서비스
//  Broadcast Extension이 저장한 프레임을 읽어와서 처리
//

import Foundation
import UIKit
import Combine

class ScreenCaptureService: ObservableObject {
    static let shared = ScreenCaptureService()

    // MARK: - Published Properties

    @Published var isBroadcasting = false
    @Published var currentFrame: UIImage?
    @Published var lastUpdateTime: Date?
    @Published var errorMessage: String?

    // MARK: - Private Properties

    private let appGroupID = "group.com.marvelcomics.translator"
    private var frameCheckTimer: Timer?
    private var lastProcessedFrameTime: Date?

    private lazy var sharedDefaults: UserDefaults? = {
        UserDefaults(suiteName: appGroupID)
    }()

    private lazy var sharedContainerURL: URL? = {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
    }()

    private init() {
        setupNotifications()
        checkBroadcastStatus()
    }

    deinit {
        stopMonitoring()
    }

    // MARK: - Public Methods

    /// 프레임 모니터링 시작
    func startMonitoring() {
        stopMonitoring()

        // 0.5초마다 새 프레임 확인
        frameCheckTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkForNewFrame()
        }

        checkBroadcastStatus()
    }

    /// 프레임 모니터링 중지
    func stopMonitoring() {
        frameCheckTimer?.invalidate()
        frameCheckTimer = nil
    }

    /// 현재 프레임 가져오기
    func getCurrentFrame() -> UIImage? {
        guard let containerURL = sharedContainerURL else {
            errorMessage = "App Group 접근 실패"
            return nil
        }

        let frameURL = containerURL.appendingPathComponent("current_frame.jpg")

        guard FileManager.default.fileExists(atPath: frameURL.path) else {
            return nil
        }

        do {
            let imageData = try Data(contentsOf: frameURL)
            return UIImage(data: imageData)
        } catch {
            errorMessage = "프레임 로드 실패: \(error.localizedDescription)"
            return nil
        }
    }

    /// 브로드캐스트 상태 확인
    func checkBroadcastStatus() {
        isBroadcasting = sharedDefaults?.bool(forKey: "isBroadcasting") ?? false
    }

    // MARK: - Private Methods

    private func setupNotifications() {
        // Darwin Notification 수신 설정
        let center = CFNotificationCenterGetDarwinNotifyCenter()

        // 브로드캐스트 시작 알림
        CFNotificationCenterAddObserver(
            center,
            Unmanaged.passUnretained(self).toOpaque(),
            { _, observer, _, _, _ in
                guard let observer = observer else { return }
                let service = Unmanaged<ScreenCaptureService>.fromOpaque(observer).takeUnretainedValue()
                DispatchQueue.main.async {
                    service.isBroadcasting = true
                    service.startMonitoring()
                }
            },
            "com.marvelcomics.translator.broadcast.started" as CFString,
            nil,
            .deliverImmediately
        )

        // 브로드캐스트 종료 알림
        CFNotificationCenterAddObserver(
            center,
            Unmanaged.passUnretained(self).toOpaque(),
            { _, observer, _, _, _ in
                guard let observer = observer else { return }
                let service = Unmanaged<ScreenCaptureService>.fromOpaque(observer).takeUnretainedValue()
                DispatchQueue.main.async {
                    service.isBroadcasting = false
                    service.stopMonitoring()
                }
            },
            "com.marvelcomics.translator.broadcast.finished" as CFString,
            nil,
            .deliverImmediately
        )
    }

    private func checkForNewFrame() {
        guard isBroadcasting else { return }

        // 마지막 프레임 시간 확인
        guard let lastFrameTime = sharedDefaults?.object(forKey: "lastFrameTime") as? Date else {
            return
        }

        // 이미 처리한 프레임인지 확인
        if let lastProcessed = lastProcessedFrameTime, lastFrameTime <= lastProcessed {
            return
        }

        // 새 프레임 로드
        if let frame = getCurrentFrame() {
            DispatchQueue.main.async {
                self.currentFrame = frame
                self.lastUpdateTime = lastFrameTime
                self.lastProcessedFrameTime = lastFrameTime
            }
        }
    }
}
