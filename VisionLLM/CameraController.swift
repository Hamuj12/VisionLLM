//
//  CameraController.swift
//  VisionLLM
//
//  Created by Hamza Mujtaba on 4/21/24.
//

import AVFoundation
import UIKit

protocol CameraControllerDelegate: AnyObject {
    func cameraController(_ controller: CameraController, didCaptureImage image: UIImage)
}

class CameraController: NSObject {
    private let captureSession = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private var backCamera: AVCaptureDevice?
    weak var delegate: CameraControllerDelegate?
    
    override init() {
        super.init()
        setupCaptureSession()
    }
    
    private func setupCaptureSession() {
        captureSession.beginConfiguration()
        let deviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .back)
        backCamera = deviceDiscoverySession.devices.first
        
        guard let backCamera = backCamera,
              let deviceInput = try? AVCaptureDeviceInput(device: backCamera),
              captureSession.canAddInput(deviceInput),
              captureSession.canAddOutput(photoOutput) else { return }
        
        captureSession.addInput(deviceInput)
        captureSession.addOutput(photoOutput)
        captureSession.commitConfiguration()
    }
    
    func startSession() {
        if !captureSession.isRunning {
            captureSession.startRunning()
        }
    }
    
    func stopSession() {
        if captureSession.isRunning {
            captureSession.stopRunning()
        }
    }
    
    func captureImage(delegate: CameraControllerDelegate) {
        self.delegate = delegate
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
}

extension CameraController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print("Error capturing photo: \(error)")
        } else if let imageData = photo.fileDataRepresentation(),
                  let image = UIImage(data: imageData) {
            delegate?.cameraController(self, didCaptureImage: image)
        }
    }
}

