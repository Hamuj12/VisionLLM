import SwiftUI
import Zip
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
    
    func exportData(completion: @escaping (Result<URL, Error>) -> Void) {
        let fileManager = FileManager.default
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let csvFileURL = documentsDirectory.appendingPathComponent("image_data.csv")
        var csvText = "ImageID,ObjectDetected,LLMOutput,TruthLabel\n"
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMddHHmmssSSS"
        var filesToZip: [URL] = []
        
        for (index, prediction) in imagePredictions.enumerated() {
            let timestamp = formatter.string(from: Date())
            let imageId = "Image_\(timestamp)_\(index)"
            let objectsDetected = prediction.predictions.map { $0.labels.first?.identifier ?? "Unknown" }.joined(separator: "; ")
            let llmOutput = llmOutputs[index]
            let truthLabel = prediction.truthLabel ?? "N/A"
            
            csvText.append("\(imageId),\"\(objectsDetected)\",\"\(llmOutput)\",\"\(truthLabel)\"\n")
            
            if let imageData = prediction.image.jpegData(compressionQuality: 0.8) {
                let imagePath = documentsDirectory.appendingPathComponent("\(imageId).jpg")
                try? imageData.write(to: imagePath)
                filesToZip.append(imagePath)
            }
        }
        
        do {
            try csvText.write(to: csvFileURL, atomically: true, encoding: .utf8)
            filesToZip.append(csvFileURL) // Add the CSV file to the list of files to zip
            
            let zipFilePath = documentsDirectory.appendingPathComponent("ExportedData.zip")
            try Zip.zipFiles(paths: filesToZip, zipFilePath: zipFilePath, password: nil, progress: nil)
            completion(.success(zipFilePath))
        } catch {
            completion(.failure(error))
        }
    }
    
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
    @State private var isExporting = false
    @State private var documentPickerPresented = false
    @State private var fileToSave: URL?
    
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
                
                Button("Export Data") {
                    viewModel.exportData { result in
                        DispatchQueue.main.async {
                            switch result {
                            case .success(let url):
                                self.fileToSave = url
                                self.documentPickerPresented = true
                            case .failure(let error):
                                print("Export failed: \(error.localizedDescription)")
                            }
                        }
                    }
                }
                .disabled(isMotionDetectionActive || viewModel.images.isEmpty)
                .sheet(isPresented: $documentPickerPresented) {
                    DocumentPicker(url: $fileToSave)
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

struct DocumentPicker: UIViewControllerRepresentable {
    @Binding var url: URL?
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forExporting: [url!], asCopy: true) // asCopy depends on whether you want to move or copy the file
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {
        // Typically you don't need to implement this method for a document picker.
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        var parent: DocumentPicker
        
        init(_ parent: DocumentPicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            // This is where you handle the user having selected a file location.
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            // Handle the user canceling the document picker
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

// PredictionView is a new struct that would need to be defined to show the predictions.
