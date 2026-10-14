import AppKit
import Vision

enum TextRecognitionService {
    static func recognizeText(in image: CGImage) throws -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([request])
        let lines = request.results?.compactMap { observation in
            observation.topCandidates(1).first?.string
        } ?? []
        return lines.joined(separator: "\n")
    }
}
