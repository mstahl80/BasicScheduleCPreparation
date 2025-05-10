// PhotoPicker.swift - Updated with camera support
import SwiftUI
import PhotosUI
#if os(iOS)
import UIKit
#else
import AppKit
#endif

struct PhotoPicker: View {
    @Binding var selectedPhotoURL: String?
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var isShowingCamera = false
    @State private var sourceType: UIImagePickerController.SourceType = .photoLibrary
    
    var body: some View {
        VStack {
            if let selectedPhotoURL, let url = URL(string: selectedPhotoURL), let imageData = try? Data(contentsOf: url), let image = Image(data: imageData) {
                image
                    .resizable()
                    .scaledToFit()
                    .frame(height: 200)
                    .cornerRadius(10)
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.gray, lineWidth: 2)
                    .frame(height: 200)
                    .overlay(
                        Text("No Receipt Image")
                            .foregroundColor(.gray)
                    )
            }
            
            #if os(iOS)
            HStack(spacing: 20) {
                PhotosPicker(selection: $selectedItem, matching: .images) {
                    Label("Gallery", systemImage: "photo")
                }
                .onChange(of: selectedItem) { _, newValue in
                    Task {
                        if let data = try? await newValue?.loadTransferable(type: Data.self) {
                            selectedImageData = data
                            saveImageToDocuments(imageData: data)
                        }
                    }
                }
                
                Button {
                    isShowingCamera = true
                } label: {
                    Label("Camera", systemImage: "camera")
                }
                .sheet(isPresented: $isShowingCamera) {
                    CameraView(selectedPhotoURL: $selectedPhotoURL)
                }
            }
            #else
            PhotosPicker(selection: $selectedItem, matching: .images) {
                Label("Select Receipt", systemImage: "photo")
            }
            .onChange(of: selectedItem) { _, newValue in
                Task {
                    if let data = try? await newValue?.loadTransferable(type: Data.self) {
                        selectedImageData = data
                        saveImageToDocuments(imageData: data)
                    }
                }
            }
            #endif
            
            if selectedPhotoURL != nil {
                Button(role: .destructive) {
                    deleteCurrentPhoto()
                } label: {
                    Label("Remove Receipt", systemImage: "trash")
                }
            }
        }
    }
    
    private func saveImageToDocuments(imageData: Data) {
        let fileName = "\(UUID().uuidString).jpg"
        let fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(fileName)
        
        do {
            try imageData.write(to: fileURL)
            selectedPhotoURL = fileURL.absoluteString
        } catch {
            print("Error saving image: \(error)")
        }
    }
    
    private func deleteCurrentPhoto() {
        if let urlString = selectedPhotoURL, let url = URL(string: urlString) {
            do {
                try FileManager.default.removeItem(at: url)
                selectedPhotoURL = nil
            } catch {
                print("Error deleting image: \(error)")
            }
        }
    }
}

#if os(iOS)
// Camera view using UIImagePickerController
struct CameraView: UIViewControllerRepresentable {
    @Binding var selectedPhotoURL: String?
    @Environment(\.presentationMode) private var presentationMode
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraView
        
        init(_ parent: CameraView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage, let data = image.jpegData(compressionQuality: 0.8) {
                saveImageToDocuments(imageData: data)
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        private func saveImageToDocuments(imageData: Data) {
            let fileName = "\(UUID().uuidString).jpg"
            let fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(fileName)
            
            do {
                try imageData.write(to: fileURL)
                parent.selectedPhotoURL = fileURL.absoluteString
            } catch {
                print("Error saving image: \(error)")
            }
        }
    }
}
#endif

// Extension to create an Image from Data (unchanged)
extension Image {
    init?(data: Data) {
        #if os(macOS)
        if let nsImage = NSImage(data: data) {
            self.init(nsImage: nsImage)
            return
        }
        #else
        if let uiImage = UIImage(data: data) {
            self.init(uiImage: uiImage)
            return
        }
        #endif
        return nil
    }
}
