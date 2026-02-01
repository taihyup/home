//
//  SampleHandler.swift
//  BroadcastExtension
//
//  화면 기록 브로드캐스트 확장
//  시스템 전체 화면을 캡처하여 메인 앱으로 전달
//

import ReplayKit
import CoreImage

class SampleHandler: RPBroadcastSampleHandler {

    // App Group을 통해 메인 앱과 데이터 공유
    private let appGroupID = "group.com.marvelcomics.translator"
    private var frameCount = 0
    private let processingInterval = 30  // 30프레임마다 처리 (약 1초에 1번)

    private lazy var sharedDefaults: UserDefaults? = {
        UserDefaults(suiteName: appGroupID)
    }()

    private lazy var sharedContainerURL: URL? = {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
    }()

    override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {
        // 브로드캐스트 시작됨
        sharedDefaults?.set(true, forKey: "isBroadcasting")
        sharedDefaults?.set(Date(), forKey: "broadcastStartTime")
        sharedDefaults?.synchronize()

        // 메인 앱에 알림
        notifyMainApp(event: "started")
    }

    override func broadcastPaused() {
        // 브로드캐스트 일시 정지
        sharedDefaults?.set(false, forKey: "isBroadcasting")
        sharedDefaults?.synchronize()
    }

    override func broadcastResumed() {
        // 브로드캐스트 재개
        sharedDefaults?.set(true, forKey: "isBroadcasting")
        sharedDefaults?.synchronize()
    }

    override func broadcastFinished() {
        // 브로드캐스트 종료
        sharedDefaults?.set(false, forKey: "isBroadcasting")
        sharedDefaults?.removeObject(forKey: "broadcastStartTime")
        sharedDefaults?.synchronize()

        // 메인 앱에 알림
        notifyMainApp(event: "finished")
    }

    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        switch sampleBufferType {
        case .video:
            // 비디오 프레임 처리
            frameCount += 1

            // 일정 간격으로만 처리 (성능 최적화)
            guard frameCount % processingInterval == 0 else { return }

            processVideoFrame(sampleBuffer)

        case .audioApp:
            // 앱 오디오 (필요시 처리)
            break

        case .audioMic:
            // 마이크 오디오 (필요시 처리)
            break

        @unknown default:
            break
        }
    }

    // MARK: - 비디오 프레임 처리

    private func processVideoFrame(_ sampleBuffer: CMSampleBuffer) {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }

        // CVPixelBuffer를 이미지 데이터로 변환
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        let context = CIContext()

        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return
        }

        // 이미지를 JPEG로 압축하여 저장 (메모리 효율)
        guard let jpegData = compressImage(cgImage, quality: 0.7) else {
            return
        }

        // App Group 공유 폴더에 이미지 저장
        saveFrameToSharedContainer(jpegData)
    }

    private func compressImage(_ cgImage: CGImage, quality: CGFloat) -> Data? {
        let uiImage = UIImage(cgImage: cgImage)
        return uiImage.jpegData(compressionQuality: quality)
    }

    private func saveFrameToSharedContainer(_ imageData: Data) {
        guard let containerURL = sharedContainerURL else { return }

        let frameURL = containerURL.appendingPathComponent("current_frame.jpg")

        do {
            try imageData.write(to: frameURL, options: .atomic)

            // 새 프레임이 저장되었음을 알림
            sharedDefaults?.set(Date(), forKey: "lastFrameTime")
            sharedDefaults?.synchronize()

        } catch {
            // 저장 실패 (무시)
        }
    }

    // MARK: - 메인 앱 알림

    private func notifyMainApp(event: String) {
        // Darwin Notification을 통해 메인 앱에 알림
        let notificationName = CFNotificationName("com.marvelcomics.translator.broadcast.\(event)" as CFString)

        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            notificationName,
            nil,
            nil,
            true
        )
    }
}

// MARK: - UIImage Extension for CGImage conversion

import UIKit

extension UIImage {
    convenience init(cgImage: CGImage) {
        self.init(cgImage: cgImage, scale: 1.0, orientation: .up)
    }
}
