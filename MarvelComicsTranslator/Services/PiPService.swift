//
//  PiPService.swift
//  MarvelComicsTranslator
//
//  Picture-in-Picture 창 관리 서비스
//  번역된 텍스트를 PiP 창으로 표시
//

import Foundation
import AVKit
import UIKit
import Combine

class PiPService: NSObject, ObservableObject {
    static let shared = PiPService()

    // MARK: - Published Properties

    @Published var isPiPActive = false
    @Published var isPiPSupported = false
    @Published var currentText: String = ""

    // MARK: - Private Properties

    private var pipController: AVPictureInPictureController?
    private var playerLayer: AVPlayerLayer?
    private var player: AVPlayer?
    private var playerLooper: AVPlayerLooper?
    private var displayLink: CADisplayLink?

    // 텍스트 렌더링을 위한 뷰
    private var textRenderView: UIView?
    private var textLabel: UILabel?

    private var cancellables = Set<AnyCancellable>()

    private override init() {
        super.init()
        checkPiPSupport()
    }

    // MARK: - Public Methods

    /// PiP 지원 여부 확인
    func checkPiPSupport() {
        isPiPSupported = AVPictureInPictureController.isPictureInPictureSupported()
    }

    /// PiP 시작 준비
    func setupPiP(in view: UIView) {
        guard isPiPSupported else {
            print("PiP is not supported on this device")
            return
        }

        // 오디오 세션 설정
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .moviePlayback)
            try audioSession.setActive(true)
        } catch {
            print("Failed to set up audio session: \(error)")
        }

        // 무음 비디오 생성 및 루프 재생
        setupSilentVideoPlayer(in: view)
    }

    /// PiP 시작
    func startPiP() {
        guard let controller = pipController else {
            print("PiP controller not initialized")
            return
        }

        if controller.isPictureInPictureActive == false {
            controller.startPictureInPicture()
        }
    }

    /// PiP 중지
    func stopPiP() {
        guard let controller = pipController else { return }

        if controller.isPictureInPictureActive {
            controller.stopPictureInPicture()
        }
    }

    /// 표시할 텍스트 업데이트
    func updateText(_ text: String) {
        currentText = text
        updateTextOverlay()
    }

    // MARK: - Private Methods

    private func setupSilentVideoPlayer(in containerView: UIView) {
        // 검은 배경의 무음 비디오 생성
        guard let videoURL = createBlackVideoURL() else {
            print("Failed to create video")
            return
        }

        let asset = AVAsset(url: videoURL)
        let playerItem = AVPlayerItem(asset: asset)

        player = AVQueuePlayer()
        guard let queuePlayer = player as? AVQueuePlayer else { return }

        playerLooper = AVPlayerLooper(player: queuePlayer, templateItem: playerItem)

        playerLayer = AVPlayerLayer(player: player)
        playerLayer?.frame = CGRect(x: 0, y: 0, width: 300, height: 100)
        playerLayer?.videoGravity = .resizeAspect

        if let layer = playerLayer {
            containerView.layer.addSublayer(layer)

            // 텍스트 오버레이 뷰 설정
            setupTextOverlay(in: containerView)

            // PiP 컨트롤러 설정
            pipController = AVPictureInPictureController(playerLayer: layer)
            pipController?.delegate = self

            // PiP에서 일시정지 버튼 숨기기
            if #available(iOS 14.2, *) {
                pipController?.requiresLinearPlayback = true
            }
        }

        player?.play()
        player?.isMuted = true
    }

    private func setupTextOverlay(in containerView: UIView) {
        textRenderView = UIView(frame: CGRect(x: 0, y: 0, width: 300, height: 100))
        textRenderView?.backgroundColor = UIColor.black.withAlphaComponent(0.8)

        textLabel = UILabel()
        textLabel?.textColor = .white
        textLabel?.font = UIFont.boldSystemFont(ofSize: 14)
        textLabel?.numberOfLines = 0
        textLabel?.textAlignment = .center
        textLabel?.translatesAutoresizingMaskIntoConstraints = false

        if let label = textLabel, let renderView = textRenderView {
            renderView.addSubview(label)

            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: renderView.leadingAnchor, constant: 8),
                label.trailingAnchor.constraint(equalTo: renderView.trailingAnchor, constant: -8),
                label.topAnchor.constraint(equalTo: renderView.topAnchor, constant: 8),
                label.bottomAnchor.constraint(equalTo: renderView.bottomAnchor, constant: -8)
            ])

            containerView.addSubview(renderView)
        }
    }

    private func updateTextOverlay() {
        DispatchQueue.main.async {
            self.textLabel?.text = self.currentText
        }
    }

    private func createBlackVideoURL() -> URL? {
        // 임시 디렉토리에 검은 비디오 파일 생성
        let tempDir = FileManager.default.temporaryDirectory
        let videoURL = tempDir.appendingPathComponent("black_video.mp4")

        // 이미 존재하면 반환
        if FileManager.default.fileExists(atPath: videoURL.path) {
            return videoURL
        }

        // 검은색 1초 비디오 생성
        return generateBlackVideo(at: videoURL) ? videoURL : nil
    }

    private func generateBlackVideo(at url: URL) -> Bool {
        let size = CGSize(width: 300, height: 100)
        let duration = CMTime(seconds: 1, preferredTimescale: 600)

        guard let writer = try? AVAssetWriter(outputURL: url, fileType: .mp4) else {
            return false
        }

        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: size.width,
            AVVideoHeightKey: size.height
        ]

        let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: writerInput,
            sourcePixelBufferAttributes: nil
        )

        writer.add(writerInput)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        // 검은 프레임 생성
        if let pixelBuffer = createBlackPixelBuffer(size: size) {
            while !writerInput.isReadyForMoreMediaData {
                Thread.sleep(forTimeInterval: 0.01)
            }
            adaptor.append(pixelBuffer, withPresentationTime: .zero)
        }

        writerInput.markAsFinished()

        let semaphore = DispatchSemaphore(value: 0)
        writer.finishWriting {
            semaphore.signal()
        }
        semaphore.wait()

        return writer.status == .completed
    }

    private func createBlackPixelBuffer(size: CGSize) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?

        let options: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ]

        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(size.width),
            Int(size.height),
            kCVPixelFormatType_32ARGB,
            options as CFDictionary,
            &pixelBuffer
        )

        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            return nil
        }

        CVPixelBufferLockBaseAddress(buffer, [])

        if let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        ) {
            context.setFillColor(UIColor.black.cgColor)
            context.fill(CGRect(origin: .zero, size: size))
        }

        CVPixelBufferUnlockBaseAddress(buffer, [])

        return buffer
    }

    // MARK: - Cleanup

    func cleanup() {
        stopPiP()
        player?.pause()
        player = nil
        playerLooper = nil
        pipController = nil
        playerLayer?.removeFromSuperlayer()
        playerLayer = nil
        textRenderView?.removeFromSuperview()
        textRenderView = nil
    }
}

// MARK: - AVPictureInPictureControllerDelegate

extension PiPService: AVPictureInPictureControllerDelegate {

    func pictureInPictureControllerWillStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        DispatchQueue.main.async {
            self.isPiPActive = true
        }
    }

    func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        DispatchQueue.main.async {
            self.isPiPActive = false
        }
    }

    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, failedToStartPictureInPictureWithError error: Error) {
        print("PiP failed to start: \(error.localizedDescription)")
        DispatchQueue.main.async {
            self.isPiPActive = false
        }
    }
}
