//
//  ModelInference.swift
//  VisionLLM
//
//  Created by Hamza Mujtaba on 4/20/24.
//

import CoreML
import Vision
import UIKit

struct ModelInference {
    var model: VNCoreMLModel

    init?(modelName: String) {
        guard let model = try? VNCoreMLModel(for: yolov8s(configuration: MLModelConfiguration()).model) else {
            print("Error setting up model")
            return nil
        }
        self.model = model
        print("Model loaded successfully")
    }

    func performInference(image: UIImage, completion: @escaping ([VNRecognizedObjectObservation]) -> Void) {
        guard let ciImage = CIImage(image: image) else {
            completion([])
            return
        }
        print("Performing inference on image")

        let request = VNCoreMLRequest(model: model) { request, error in
            if let error = error {
                print("Model failed to process image: \(error.localizedDescription)")
                completion([])
            } else if let results = request.results as? [VNRecognizedObjectObservation] {
                if results.isEmpty {
                    print("Inference completed but no objects were detected.")
                } else {
                    print("Inference completed successfully, found \(results.count) objects.")
                }
                completion(results)
                self.printResults(results)
            } else {
                print("No results or an unknown error occurred")
                completion([])
            }
        }

        request.imageCropAndScaleOption = .scaleFill

        let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
        DispatchQueue.global().async {
            try? handler.perform([request])
        }
    }
    
    private func printResults(_ results: [VNRecognizedObjectObservation]) {
        print("Inference Results:")
        for result in results {
            print("Identified Object: \(result.labels.first?.identifier ?? "Unknown")")
            print("Confidence: \(result.confidence)")
            print("Bounding Box: \(result.boundingBox)")
            print("---")
        }
    }
}
