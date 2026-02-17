import SwiftUI
import PhotosUI

struct HerbariumView: View {
    @State private var appState = AppState.shared
    @State private var showCamera = false
    @State private var selectedImage: UIImage?
    @State private var showNewEntry = false

    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {

                VStack(alignment: .leading, spacing: 8) {
                    Text("Digitales Herbarium")
                        .font(.largeTitle.bold())
                    Text("Sammle Blätter und erhalte Abzeichen!")
                        .font(.hostGrotesk(.subheadline))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()

                LazyVGrid(columns: columns, spacing: 16) {

                    Button {
                        showCamera = true
                    } label: {
                        VStack {
                            Image(systemName: "camera.fill")
                                .font(.hostGrotesk(.largeTitle))
                                .foregroundStyle(.white)
                            Text("Blatt scannen")
                                .font(.hostGrotesk(.headline, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                        .frame(height: 180)
                        .frame(maxWidth: .infinity)
                        .background(
                            LinearGradient(
                                colors: [.green, .mint],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .green.opacity(0.3), radius: 8, y: 4)
                    }

                    ForEach(appState.herbariumEntries) { entry in
                        HerbariumCard(entry: entry)
                    }
                }
                .padding()
            }
        }
        .background(Color(UIColor.systemGroupedBackground))
        .sheet(isPresented: $showCamera) {
            HerbariumImagePicker(image: $selectedImage)
        }
        .onChange(of: selectedImage) { _, newImage in
            if let image = newImage {
                saveEntry(image: image)
            }
        }
        .sheet(isPresented: $showNewEntry) {
            if let last = appState.herbariumEntries.last {
                NewEntryView(entry: last)
            }
        }
    }

    private func saveEntry(image: UIImage) {

        guard let data = image.jpegData(compressionQuality: 0.7) else { return }
        let filename = UUID().uuidString + ".jpg"
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(filename)

        do {
            try data.write(to: url)
            let entry = HerbariumEntry(imagePath: filename)
            appState.herbariumEntries.append(entry)
            showNewEntry = true
            selectedImage = nil
        } catch {
            print("Error saving image: \(error)")
        }
    }
}

struct HerbariumCard: View {
    let entry: HerbariumEntry

    var body: some View {
        VStack(spacing: 0) {

            if let image = loadImage() {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 140)
                    .clipped()
            } else {
                Rectangle()
                    .fill(.gray.opacity(0.2))
                    .frame(height: 140)
                    .overlay(Image(systemName: "photo").foregroundStyle(.secondary))
            }

            HStack {
                Text(entry.emojiBadge)
                    .font(.hostGrotesk(.title))
                Spacer()
                Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.hostGrotesk(.caption))
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .background(.white)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.1), radius: 5, y: 2)
    }

    private func loadImage() -> UIImage? {

        if let data = entry.photoData {
            return UIImage(data: data)
        }

        guard let imagePath = entry.imagePath else { return nil }
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(imagePath)
        if let data = try? Data(contentsOf: url) {
            return UIImage(data: data)
        }
        return nil
    }
}

struct NewEntryView: View {
    let entry: HerbariumEntry
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 24) {
            Text("🎉 Neues Blatt gesammelt!")
                .font(.title.bold())
                .multilineTextAlignment(.center)

            Text(entry.emojiBadge)
                .font(.system(size: 100))
                .shadow(radius: 10)

            Text("Du hast ein neues Abzeichen erhalten!")
                .font(.hostGrotesk(.headline, weight: .semibold))
                .foregroundStyle(.secondary)

            Button("Super!") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding()
    }
}

struct HerbariumImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.presentationMode) var presentationMode

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator

        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            picker.sourceType = .camera
        } else {
            picker.sourceType = .photoLibrary
        }
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: HerbariumImagePicker

        init(_ parent: HerbariumImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
            }
            parent.presentationMode.wrappedValue.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}
