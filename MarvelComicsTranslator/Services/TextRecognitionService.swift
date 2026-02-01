//
//  TextRecognitionService.swift
//  MarvelComicsTranslator
//
//  Apple Vision Framework를 사용한 OCR 텍스트 인식 서비스
//  만화 이미지에서 영어 텍스트를 추출
//

import Foundation
import Vision
import UIKit

class TextRecognitionService: ObservableObject {
    static let shared = TextRecognitionService()

    @Published var isProcessing = false
    @Published var progress: Double = 0

    private init() {}

    // MARK: - 텍스트 인식

    /// 이미지에서 텍스트 인식
    func recognizeText(from imageData: Data) async throws -> [RecognizedTextBlock] {
        guard let uiImage = UIImage(data: imageData),
              let cgImage = uiImage.cgImage else {
            throw TextRecognitionError.invalidImage
        }

        return try await recognizeText(from: cgImage)
    }

    /// CGImage에서 텍스트 인식
    func recognizeText(from cgImage: CGImage) async throws -> [RecognizedTextBlock] {
        await MainActor.run {
            isProcessing = true
            progress = 0
        }

        defer {
            Task { @MainActor in
                isProcessing = false
                progress = 1.0
            }
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: TextRecognitionError.recognitionFailed(error.localizedDescription))
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: [])
                    return
                }

                let textBlocks = self.processObservations(observations)
                continuation.resume(returning: textBlocks)
            }

            // 텍스트 인식 설정
            request.recognitionLevel = .accurate  // 정확도 우선
            request.recognitionLanguages = ["en-US"]  // 영어 인식
            request.usesLanguageCorrection = true  // 언어 보정 사용

            // 만화 텍스트에 맞는 추가 설정
            request.minimumTextHeight = 0.01  // 작은 텍스트도 인식

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: TextRecognitionError.recognitionFailed(error.localizedDescription))
            }
        }
    }

    /// VNRecognizedTextObservation을 RecognizedTextBlock으로 변환
    private func processObservations(_ observations: [VNRecognizedTextObservation]) -> [RecognizedTextBlock] {
        var textBlocks: [RecognizedTextBlock] = []

        for observation in observations {
            // 가장 높은 신뢰도의 텍스트 후보 선택
            guard let topCandidate = observation.topCandidates(1).first else {
                continue
            }

            // 신뢰도가 낮은 텍스트 필터링
            guard topCandidate.confidence > 0.3 else {
                continue
            }

            // 빈 텍스트나 너무 짧은 텍스트 필터링
            let text = topCandidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard text.count >= 2 else {
                continue
            }

            // Vision의 좌표계를 일반 좌표계로 변환
            // Vision: 좌하단 (0,0), 일반: 좌상단 (0,0)
            let boundingBox = observation.boundingBox
            let convertedBox = CGRect(
                x: boundingBox.origin.x,
                y: 1 - boundingBox.origin.y - boundingBox.height,
                width: boundingBox.width,
                height: boundingBox.height
            )

            let textBlock = RecognizedTextBlock(
                text: text,
                boundingBox: convertedBox,
                confidence: topCandidate.confidence
            )

            textBlocks.append(textBlock)
        }

        // 상단에서 하단으로, 왼쪽에서 오른쪽으로 정렬
        return textBlocks.sorted { block1, block2 in
            if abs(block1.boundingBox.minY - block2.boundingBox.minY) < 0.02 {
                return block1.boundingBox.minX < block2.boundingBox.minX
            }
            return block1.boundingBox.minY < block2.boundingBox.minY
        }
    }

    // MARK: - 말풍선 영역 감지 (향상된 기능)

    /// 말풍선 영역 감지하여 텍스트 그룹화
    func groupTextBlocksInSpeechBubbles(_ blocks: [RecognizedTextBlock]) -> [[RecognizedTextBlock]] {
        guard !blocks.isEmpty else { return [] }

        var groups: [[RecognizedTextBlock]] = []
        var remainingBlocks = blocks

        while !remainingBlocks.isEmpty {
            var currentGroup: [RecognizedTextBlock] = [remainingBlocks.removeFirst()]
            var i = 0

            while i < remainingBlocks.count {
                let block = remainingBlocks[i]

                // 현재 그룹의 텍스트들과 근접한지 확인
                let isNearby = currentGroup.contains { existingBlock in
                    isNearby(block.boundingBox, existingBlock.boundingBox)
                }

                if isNearby {
                    currentGroup.append(block)
                    remainingBlocks.remove(at: i)
                } else {
                    i += 1
                }
            }

            groups.append(currentGroup)
        }

        return groups
    }

    /// 두 영역이 근접한지 확인
    private func isNearby(_ rect1: CGRect, _ rect2: CGRect, threshold: CGFloat = 0.05) -> Bool {
        let expandedRect1 = rect1.insetBy(dx: -threshold, dy: -threshold)
        return expandedRect1.intersects(rect2)
    }
}

// MARK: - Text Recognition Errors

enum TextRecognitionError: Error, LocalizedError {
    case invalidImage
    case recognitionFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "이미지를 처리할 수 없습니다"
        case .recognitionFailed(let message):
            return "텍스트 인식 실패: \(message)"
        }
    }
}
