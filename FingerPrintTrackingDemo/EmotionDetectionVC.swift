//
//  EmotionDetectionVC.swift
//  FingerPrintTrackingDemo
//
//  Created by DREAMWORLD on 18/11/24.
//

import UIKit
import AVFoundation
import Vision

class EmotionDetectionVC: UIViewController {

    private let previewView = UIView()
    private let emotionLabel = UILabel()

    private let captureSession = AVCaptureSession()

    override func viewDidLoad() {
        super.viewDidLoad()

        setupUI()
        setupCamera()
    }

    private func setupUI() {
        view.addSubview(previewView)
        previewView.frame = view.bounds

        emotionLabel.text = "Detecting..."
        emotionLabel.textAlignment = .center
        emotionLabel.font = UIFont.boldSystemFont(ofSize: 24)
        emotionLabel.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        emotionLabel.textColor = .white
        emotionLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(emotionLabel)

        NSLayoutConstraint.activate([
            emotionLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            emotionLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emotionLabel.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.8),
            emotionLabel.heightAnchor.constraint(equalToConstant: 50)
        ])
    }

    private func setupCamera() {
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let videoInput = try? AVCaptureDeviceInput(device: videoDevice),
              captureSession.canAddInput(videoInput) else {
            print("Camera setup failed")
            return
        }

        captureSession.addInput(videoInput)

        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }

        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = previewView.bounds
        previewLayer.videoGravity = .resizeAspectFill
        previewView.layer.addSublayer(previewLayer)

        captureSession.startRunning()
    }

}

extension EmotionDetectionVC: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let request = VNDetectFaceLandmarksRequest { [weak self] request, error in
            guard let self = self else { return }
            if let results = request.results as? [VNFaceObservation], let face = results.first {
                self.detectEmotion(from: face, pixelBuffer: pixelBuffer)
            }
        }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        try? handler.perform([request])
    }

    private func detectEmotion(from face: VNFaceObservation, pixelBuffer: CVPixelBuffer) {
//        guard let model = try? VNCoreMLModel(for: EmotionClassifier().model) else { return }
//
//        let request = VNCoreMLRequest(model: model) { [weak self] request, error in
//            guard let self = self else { return }
//            if let results = request.results as? [VNClassificationObservation], let topResult = results.first {
//                DispatchQueue.main.async {
//                    self.emotionLabel.text = "Emotion: \(topResult.identifier) (\(Int(topResult.confidence * 100))%)"
//                }
//            }
//        }
//
//        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
//        try? handler.perform([request])
    }

}


