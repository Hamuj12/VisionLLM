//
//  GalleryView.swift
//  VisionLLM
//
//  Created by Hamza Mujtaba on 4/21/24.
//

import SwiftUI

struct GalleryView: View {
    @ObservedObject var viewModel: ViewModel
    let llmOutputs: [String]

    var body: some View {
        NavigationView {
            List(viewModel.imagePredictions.indices, id: \.self) { index in
                VStack {
                    NavigationLink(destination: ImageDetailView(imagePrediction: viewModel.imagePredictions[index], llmOutput: llmOutputs[index])) {
                        HStack {
                            Image(uiImage: viewModel.imagePredictions[index].image)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 100, height: 100)
                            VStack(alignment: .leading) {
                                Text("Objects Detected: \(viewModel.imagePredictions[index].predictions.count)")
                                Text("First Object: \(viewModel.imagePredictions[index].predictions.first?.labels.first?.identifier ?? "N/A")")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                Text("LLM Output: \(llmOutputs[index])")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                TextField("Enter truth label", text: Binding(
                                    get: { viewModel.imagePredictions[index].truthLabel ?? "" },
                                    set: { viewModel.updateTruthLabel(for: viewModel.imagePredictions[index].id, with: $0) }
                                ))
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .padding(.top, 5)
                            }
                        }
                    }
                }
            }
            .navigationBarTitle("Gallery", displayMode: .inline)
        }
    }
}
