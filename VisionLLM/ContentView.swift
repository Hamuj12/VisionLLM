import SwiftUI
import Vision
import AVFoundation

class CameraDelegateHandler: NSObject, CameraControllerDelegate {
    var viewModel: ViewModel?
    
    func cameraController(_ controller: CameraController, didCaptureImage image: UIImage) {
        viewModel?.addImage(image)
    }
}

class ViewModel: ObservableObject {
    @Published var images: [UIImage] = []
    @Published var imagePredictions: [ImagePrediction] = []
    @Published var llmOutputs: [String] = [] // Store LLM outputs for each image
    
    func addImage(_ image: UIImage) {
        images.append(image)
        processImage(image)
    }
    
    // Method to update the truth label for a specific ImagePrediction
    func updateTruthLabel(for id: UUID, with label: String) {
        if let index = imagePredictions.firstIndex(where: { $0.id == id }) {
            imagePredictions[index].truthLabel = label
        }
    }
    
    private func processImage(_ img: UIImage) {
        let inference = ModelInference(modelName: "YOLOv8s_world")
        inference?.performInference(image: img) { [weak self] results in
            DispatchQueue.main.async {
                let prediction = ImagePrediction(image: img, predictions: results)
                self?.imagePredictions.append(prediction)
                self?.generateLLMPrompt(for: prediction)
            }
        }
    }
    
    private func generateLLMPrompt(for prediction: ImagePrediction) {
        let objects = prediction.predictions.map { $0.topLabel } // Assumes topLabel is already computed as the most likely label
        let modelHandler = ModelHandler()
        modelHandler.predictCompletion(for: objects) { [weak self] (result, error) in
            DispatchQueue.main.async {
                if let result = result {
                    self?.llmOutputs.append(result)
                } else {
                    self?.llmOutputs.append("Error: \(error?.localizedDescription ?? "unknown error")")
                }
            }
        }
    }
}



struct ContentView: View {
    @ObservedObject var viewModel = ViewModel()
    @State private var isMotionDetectionActive = false
    @State private var isCameraAuthorized = false
    @State private var showingGallery = false
    
    private let motionManager = MotionManager()
    private let cameraController = CameraController()
    private var cameraDelegateHandler = CameraDelegateHandler()
    
    var body: some View {
        NavigationView {
            VStack {
                if let latestImage = viewModel.images.last,
                   let latestLLMOutput = viewModel.llmOutputs.last {
                    Image(uiImage: latestImage)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 300)
                    Text(latestLLMOutput)
                        .padding()
                } else {
                    Text("No image captured yet.")
                }
                
                Button("Start/Stop Motion Detection") {
                    toggleMotionDetection()
                }
                
                Button("View Gallery") {
                    showingGallery = true
                }
                .disabled(viewModel.images.isEmpty)
                .sheet(isPresented: $showingGallery) {
                    // Pass the entire ViewModel to maintain state across components.
                    GalleryView(viewModel: viewModel, llmOutputs: viewModel.llmOutputs)
                }
            }
            .navigationBarTitle("Vision LLM", displayMode: .inline)
            .onAppear {
                checkCameraAuthorization()
            }
        }
    }
    
    private func toggleMotionDetection() {
        isMotionDetectionActive.toggle()
        if isMotionDetectionActive {
            startMotionDetection()
        } else {
            stopMotionDetection()
        }
    }
    
    private func startMotionDetection() {
        guard isCameraAuthorized else { return }
        cameraDelegateHandler.viewModel = viewModel
        cameraController.delegate = cameraDelegateHandler
        cameraController.startSession()
        motionManager.motionHandler = {
            self.cameraController.captureImage(delegate: self.cameraDelegateHandler)
        }
    }
    
    private func stopMotionDetection() {
        cameraController.stopSession()
        motionManager.motionHandler = nil
    }
    
    private func checkCameraAuthorization() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isCameraAuthorized = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    self.isCameraAuthorized = granted
                }
            }
        case .denied, .restricted:
            isCameraAuthorized = false
        default:
            isCameraAuthorized = false
        }
    }
}

// PredictionView is a new struct that would need to be defined to show the predictions.
