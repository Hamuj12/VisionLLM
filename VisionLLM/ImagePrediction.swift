//
//  ImagePrediction.swift
//  VisionLLM
//
//  Created by Hamza Mujtaba on 4/21/24.
//

import UIKit
import Vision

struct ImagePrediction: Identifiable {
    let id = UUID()
    let image: UIImage
    let predictions: [VNRecognizedObjectObservation]
    var truthLabel: String?
}
