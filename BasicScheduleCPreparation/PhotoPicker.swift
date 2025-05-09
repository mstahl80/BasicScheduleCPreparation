// PhotoPicker.swift - Updated with the new onChange API
import SwiftUI
import PhotosUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct PhotoPicker: View {
    @Binding var selectedPhotoURL: String?
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    
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
            
            PhotosPicker(selection: $selectedItem, matching: .images) {
                Label("Select Receipt", systemImage: "photo")
            }
            // Updated onChange for newer SwiftUI versions
            .onChange(of: selectedItem) { _, newValue in
                Task {
                    if let data = try? await newValue?.loadTransferable(type: Data.self) {
                        selectedImageData = data
                        saveImageToDocuments(imageData: data)
                    }
                }
            }
            
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

// Extension to create an Image from Data
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
