//
//  PredictionView.swift
//  VisionLLM
//
//  Created by Hamza Mujtaba on 4/21/24.
//

import SwiftUI
import Vision

struct PredictionView: View {
    let predictions: [VNRecognizedObjectObservation]

    var body: some View {
        List(predictions, id: \.uuid) { prediction in
            HStack {
                Text(prediction.topLabel)
                Spacer()
                Text(String(format: "%.2f%%", prediction.confidence * 100))
                    .foregroundColor(.gray)
            }
        }
    }
}

extension VNRecognizedObjectObservation {
    // Helper to get the top label of the prediction.
    var topLabel: String {
        return self.labels.first?.identifier ?? "Unknown"
    }
}
