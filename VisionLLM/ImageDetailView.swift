//
//  ImageDetailView.swift
//  VisionLLM
//
//  Created by Hamza Mujtaba on 4/21/24.
//

import SwiftUI

struct ImageDetailView: View {
    var imagePrediction: ImagePrediction
    var llmOutput: String

    var body: some View {
        VStack {
            Image(uiImage: imagePrediction.image)
                .resizable()
                .scaledToFit()
            
            List {
                ForEach(imagePrediction.predictions, id: \.uuid) { prediction in
                    Text("Object: \(prediction.labels.first?.identifier ?? "Unknown"), Confidence: \(prediction.confidence)")
                }
                Text("LLM Prediction: \(llmOutput)")
                    .font(.headline)
                    .foregroundColor(.secondary)
                if let truthLabel = imagePrediction.truthLabel {
                    Text("Truth Label: \(truthLabel)")
                        .font(.headline)
                        .foregroundColor(.green)
                }
            }
        }
    }
}
