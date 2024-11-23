//
//  ViewController.swift
//  FingerPrintTrackingDemo
//
//  Created by DREAMWORLD on 12/11/24.
//

import UIKit
import AVFoundation
import Vision

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {

    private var drawingLayers: [CAShapeLayer] = []

    private var lastIndexTipPositions: [CGPoint] = []
    private let smoothingCount = 5

    private var captureSession: AVCaptureSession!
    private var previewLayer: AVCaptureVideoPreviewLayer!
    private var drawingPath = UIBezierPath()
    private var isDrawing = false
    private var lastPoint: CGPoint?
    private var drawingIndicator: UIView!

    private let handPoseRequest = VNDetectHumanHandPoseRequest()

    private let joinThreshold: CGFloat = 0.05  // Adjust this as needed

    override func viewDidLoad() {
        super.viewDidLoad()

        self.setupCamera()
        handPoseRequest.maximumHandCount = 1

        self.setupDrawingIndicator()
        self.addMarker()
        self.addClearButton()
    }

    private func addClearButton() {
        let clearButton = UIButton(type: .system)
        clearButton.setTitle("Clear Drawings", for: .normal)
        clearButton.backgroundColor = .white
        clearButton.setTitleColor(.black, for: .normal)
        clearButton.layer.cornerRadius = 20
        clearButton.translatesAutoresizingMaskIntoConstraints = false
        clearButton.addTarget(self, action: #selector(clearDrawings), for: .touchUpInside)

        self.view.addSubview(clearButton)

        // Set constraints
        NSLayoutConstraint.activate([
            clearButton.bottomAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            clearButton.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
            clearButton.widthAnchor.constraint(equalToConstant: 150),
            clearButton.heightAnchor.constraint(equalToConstant: 40)
        ])
    }

    private func setupCamera() {
        captureSession = AVCaptureSession()
        captureSession.sessionPreset = .high

        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let videoInput = try? AVCaptureDeviceInput(device: videoDevice) else { return }

        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        }

        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.videoSettings = [(kCVPixelBufferPixelFormatTypeKey as NSString) : NSNumber(value: kCVPixelFormatType_32BGRA)] as [String : Any]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "frame_pqueue"))

        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }

        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.bounds
        previewLayer.videoGravity = .resizeAspectFill
//        previewLayer.opacity = 0.5
        view.layer.addSublayer(previewLayer)

        captureSession.startRunning()
    }

    private func setupDrawingIndicator() {
        drawingIndicator = UIView()
        drawingIndicator.frame.size = CGSize(width: 20, height: 20)
        drawingIndicator.backgroundColor = UIColor.red.withAlphaComponent(0.7)
        drawingIndicator.layer.cornerRadius = 10
        drawingIndicator.isHidden = true // Hidden by default
        view.addSubview(drawingIndicator)
    }

    // Capture video frames
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            self.detectHandPose(in: pixelBuffer)
        }
    }
}

extension ViewController {
    private func detectHandPose(in pixelBuffer: CVPixelBuffer) {

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        do {
            try handler.perform([handPoseRequest])
            guard let observation = handPoseRequest.results?.first else {
                print("hand : \(handPoseRequest.results ?? [])")
                DispatchQueue.main.async {
                    self.drawingIndicator.isHidden = true
                    self.isDrawing = false
                    self.lastPoint = nil
                }
                return
            }
            DispatchQueue.main.async {
                self.processHandPose(observation: observation)
            }
        } catch {
            print("Error in hand pose detection: \(error)")
        }
    }

    private func processHandPose(observation: VNHumanHandPoseObservation) {

        print("============================================")
        if let firstFTip = try? observation.recognizedPoint(.indexTip) {
            print("Index Tip Confidance : \(firstFTip.confidence)")
        }
//        if let ṃiddleFTip = try? observation.recognizedPoint(.middleTip) {
//            print("Middle Tip Confidance : \(ṃiddleFTip.confidence)")
//        }
//        if let ringFTip = try? observation.recognizedPoint(.ringTip) {
//            print("Ring Tip Confidance : \(ringFTip.confidence)")
//        }
//        if let littleFTip = try? observation.recognizedPoint(.littleTip) {
//            print("Little Tip Confidance : \(littleFTip.confidence)")
//        }
        if let thumbFTip = try? observation.recognizedPoint(.thumbTip) {
            print("Thumb Tip Confidance : \(thumbFTip.confidence)")
        }
        if let wrist = try? observation.recognizedPoint(.wrist) {
            print("Wrist Tip Confidance : \(wrist.confidence)")
        }


        // Detect index tip and thumb tip
        guard let indexTip = try? observation.recognizedPoint(.indexTip), indexTip.confidence > 0.8,
              let thumbTip = try? observation.recognizedPoint(.thumbTip), thumbTip.confidence > 0.5 else {
            DispatchQueue.main.async {
                self.drawingIndicator.isHidden = true
                self.isDrawing = false
                self.lastPoint = nil
                self.lastIndexTipPositions.removeAll()
            }
            return
        }

        // Calculate distance between index tip and thumb tip
        let distance = hypot(indexTip.location.x - thumbTip.location.x, indexTip.location.y - thumbTip.location.y)

        // Check if the points are close enough to start drawing
        //print("Distace : \(distance) && Threshold : \(joinThreshold)")
        if distance < joinThreshold {
            guard var indexPoint = self.convertToViewCoordinates(point: indexTip) else { return }
            indexPoint = smoothedPosition(for: indexPoint)

            DispatchQueue.main.async {
                self.drawingIndicator.isHidden = false
                self.drawingIndicator.center = indexPoint  // Update indicator if needed
                self.isDrawing = true

                // Draw line if drawing mode is enabled
                if self.isDrawing {
                    self.drawLine(from: self.lastPoint ?? indexPoint, to: indexPoint)
                    self.lastPoint = indexPoint
                } else {
                    self.lastPoint = indexPoint
                }
            }
        } else {
            // If fingers are not joined, stop drawing
            DispatchQueue.main.async {
                self.drawingIndicator.isHidden = true
                self.isDrawing = false
                self.lastPoint = nil
                self.lastIndexTipPositions.removeAll()
            }
        }
    }

    // Function to draw a line from the previous point to the current point
    private func drawLine(from startPoint: CGPoint, to endPoint: CGPoint) {
        let path = UIBezierPath()
        path.move(to: startPoint)
        path.addLine(to: endPoint)

        let shapeLayer = CAShapeLayer()
        shapeLayer.path = path.cgPath
        shapeLayer.strokeColor = UIColor.cyan.cgColor
        shapeLayer.lineWidth = 3.0
        shapeLayer.fillColor = UIColor.clear.cgColor
        self.view.layer.addSublayer(shapeLayer)
        drawingLayers.append(shapeLayer)
    }

    private func convertToViewCoordinates(point: VNRecognizedPoint?) -> CGPoint? {
        guard let point else {
            return nil
        }
        if point.confidence < 0.5 {
            return nil
        }

        // Convert point to view coordinates
        let convertedPoint = previewLayer.layerPointConverted(fromCaptureDevicePoint: CGPoint(x: point.location.x, y: point.location.y))

        // Mirror X-coordinate for front camera use
        let mirroredX = view.bounds.width - convertedPoint.x
        return CGPoint(x: mirroredX, y: convertedPoint.y)
    }

    private func smoothedPosition(for point: CGPoint) -> CGPoint {
        lastIndexTipPositions.append(point)
        if lastIndexTipPositions.count > smoothingCount {
            lastIndexTipPositions.removeFirst()
        }
        let avgX = lastIndexTipPositions.map { $0.x }.reduce(0, +) / CGFloat(lastIndexTipPositions.count)
        let avgY = lastIndexTipPositions.map { $0.y }.reduce(0, +) / CGFloat(lastIndexTipPositions.count)
        return CGPoint(x: avgX, y: avgY)
    }

    private func addMarker() {
        self.drawingIndicator.removeFromSuperview()

        let marker = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: 10))
        marker.backgroundColor = .red
        marker.layer.cornerRadius = 5
        self.drawingIndicator = marker

        // Add marker to the view
        self.view.addSubview(marker)
    }

    @objc private func clearDrawings() {
        drawingLayers.forEach { $0.removeFromSuperlayer() }
        drawingLayers.removeAll()
        lastIndexTipPositions.removeAll()
    }

//    private func processHandPose(observation: VNHumanHandPoseObservation) {
//        guard
//              let indexTip = try? observation.recognizedPoint(.indexTip) else { return }
////        print("thumb tip : \(thumbTip.location)")
//        print("index tip : \(indexTip.location)")
//
////        if thumbTip.confidence > 0.8 && indexTip.confidence > 0.8 {
//            DispatchQueue.main.async {
////                let thumbPoint = self.convertToViewCoordinates(point: thumbTip.location)
//                let indexPoint = self.convertToViewCoordinates(point: indexTip.location)
////                print("thumb point : \(thumbPoint)")
//                print("index point : \(indexPoint)")
//
//                // Check distance between thumb and index tip to enable drawing
////                let distance = hypot(thumbPoint.x - indexPoint.x, thumbPoint.y - indexPoint.y)
////                print(distance)
////                if distance < 40 { // threshold for "pinching" action
//                    self.isDrawing = true
//                    self.drawingIndicator.isHidden = false
//                    self.drawingIndicator.center = indexPoint
//                    self.drawLine(from: self.lastPoint ?? indexPoint, to: indexPoint)
//                    self.lastPoint = indexPoint
////                } else {
////                    self.isDrawing = false
////                    self.lastPoint = nil
////                    self.drawingIndicator.isHidden = true
////                }
//            }
////        }
//    }
//
//    private func convertToViewCoordinates(point: CGPoint) -> CGPoint {
//        return CGPoint(x: point.x * view.bounds.width, y: (1 - point.y) * view.bounds.height)
//    }

//
//    private func drawLine(from startPoint: CGPoint, to endPoint: CGPoint) {
////        DispatchQueue.main.async {
//            let path = UIBezierPath()
//            path.move(to: startPoint)
//            path.addLine(to: endPoint)
//
//            let shapeLayer = CAShapeLayer()
//            shapeLayer.path = path.cgPath
//            shapeLayer.strokeColor = UIColor.blue.cgColor
//            shapeLayer.lineWidth = 2.0
//            shapeLayer.fillColor = UIColor.clear.cgColor
//            self.view.layer.addSublayer(shapeLayer)
//
//            self.drawingPath.append(path)
////        }
//    }
}

