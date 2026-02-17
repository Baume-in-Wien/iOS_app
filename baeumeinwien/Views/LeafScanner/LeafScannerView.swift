import SwiftUI
import PhotosUI

struct LeafScannerView: View {
    @State private var classificationService = LeafClassificationService.shared
    @State private var showCamera = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var capturedImage: UIImage?

    @State private var appeared = false
    @State private var ringRotation: Double = 0

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundGradient.ignoresSafeArea()

                if classificationService.lastResults.isEmpty && !classificationService.isClassifying {
                    emptyStateView
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                } else {
                    resultStateView
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .animation(.easeInOut(duration: 0.45), value: classificationService.lastResults.isEmpty)
            .animation(.easeInOut(duration: 0.3), value: classificationService.isClassifying)
            .navigationTitle("Blatt-Scanner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                if !classificationService.lastResults.isEmpty {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            classificationService.reset()
                            capturedImage = nil
                        } label: {
                            Image(systemName: "arrow.counterclockwise")
                        }
                    }
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                LeafCameraView { image in
                    capturedImage = image
                    classificationService.classify(image: image)
                }
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        capturedImage = image
                        classificationService.classify(image: image)
                    }
                }
                selectedPhotoItem = nil
            }
        }
    }

    private var backgroundGradient: some View {
        LinearGradient(
            stops: [
                .init(color: Color(.systemBackground), location: 0),
                .init(color: .green.opacity(0.03), location: 0.25),
                .init(color: .green.opacity(0.07), location: 0.55),
                .init(color: .mint.opacity(0.04), location: 0.8),
                .init(color: Color(.systemBackground), location: 1.0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var emptyStateView: some View {
        GeometryReader { geo in
            let compact = geo.size.height < 700
            VStack(spacing: 0) {

                VStack(alignment: .leading, spacing: 6) {
                    Text("BLATT\nERKENNUNG")
                        .font(.hostGrotesk(.largeTitle, weight: .black))
                        .lineSpacing(-2)
                    Text("Fotografiere ein Blatt und\nerkenne die Baumart")
                        .font(.hostGrotesk(.subheadline))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, compact ? 8 : 16)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 16)

                Spacer(minLength: compact ? 12 : 24)

                ZStack {

                    Circle()
                        .stroke(
                            AngularGradient(
                                colors: [
                                    .green.opacity(0.5), .green.opacity(0.05),
                                    .mint.opacity(0.25), .green.opacity(0.05),
                                    .green.opacity(0.5)
                                ],
                                center: .center
                            ),
                            lineWidth: 2.5
                        )
                        .frame(width: compact ? 140 : 170, height: compact ? 140 : 170)
                        .rotationEffect(.degrees(ringRotation))

                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.green.opacity(0.12), .clear],
                                center: .center, startRadius: 10, endRadius: 70
                            )
                        )
                        .frame(width: compact ? 120 : 150, height: compact ? 120 : 150)

                    Image(systemName: "leaf.fill")
                        .font(.system(size: compact ? 48 : 60))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.green, .green.opacity(0.65)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .symbolEffect(.pulse)
                }
                .opacity(appeared ? 1 : 0)
                .scaleEffect(appeared ? 1 : 0.85)

                Spacer(minLength: compact ? 12 : 24)

                VStack(spacing: compact ? 10 : 14) {
                    stepRow(number: 1, icon: "camera.fill", text: "Fotografiere ein einzelnes Blatt")
                    stepRow(number: 2, icon: "sparkles", text: "KI erkennt die Baumart")
                    stepRow(number: 3, icon: "tree.fill", text: "Finde passende Bäume auf der Karte")
                }
                .padding(.horizontal, 24)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 12)

                Spacer(minLength: compact ? 16 : 28)

                VStack(spacing: 10) {
                    Button {
                        showCamera = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "camera.fill")
                                .font(.hostGrotesk(.body, weight: .semibold))
                            Text("Foto aufnehmen")
                                .font(.hostGrotesk(.body, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            LinearGradient(
                                colors: [.green, .green.opacity(0.85)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ),
                            in: RoundedRectangle(cornerRadius: 26)
                        )
                        .shadow(color: .green.opacity(0.3), radius: 12, y: 6)
                    }
                    .buttonStyle(GlassPressStyle())

                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        HStack(spacing: 8) {
                            Image(systemName: "photo.on.rectangle")
                                .font(.hostGrotesk(.body, weight: .semibold))
                            Text("Aus Galerie wählen")
                                .font(.hostGrotesk(.body, weight: .semibold))
                        }
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26))
                        .overlay(
                            RoundedRectangle(cornerRadius: 26)
                                .stroke(LiquidGlass.highlightGradient, lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(GlassPressStyle())
                }
                .padding(.horizontal, 24)
                .padding(.bottom, compact ? 16 : 28)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 16)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.7)) {
                appeared = true
            }
            withAnimation(.linear(duration: 10).repeatForever(autoreverses: false)) {
                ringRotation = 360
            }
        }
    }

    private func stepRow(number: Int, icon: String, text: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.green.opacity(0.18), .green.opacity(0.06)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.hostGrotesk(.subheadline, weight: .semibold))
                    .foregroundStyle(.green)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text("Schritt \(number)")
                    .font(.hostGrotesk(.caption2, weight: .semibold))
                    .foregroundStyle(.green.opacity(0.8))
                Text(text)
                    .font(.hostGrotesk(.subheadline))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var resultStateView: some View {
        ScrollView {
            VStack(spacing: 16) {

                if let image = capturedImage {
                    ZStack(alignment: .bottom) {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 260)
                            .clipShape(RoundedRectangle(cornerRadius: 24))

                        LinearGradient(
                            colors: [.clear, .clear, Color(.systemBackground).opacity(0.85)],
                            startPoint: .top, endPoint: .bottom
                        )
                        .frame(height: 100)
                        .clipShape(
                            UnevenRoundedRectangle(
                                bottomLeadingRadius: 24,
                                bottomTrailingRadius: 24
                            )
                        )
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(LiquidGlass.highlightGradient, lineWidth: 0.5)
                    )
                    .shadow(color: .black.opacity(0.12), radius: 20, y: 10)
                    .padding(.horizontal)
                }

                if classificationService.isClassifying {
                    VStack(spacing: 14) {
                        ProgressView()
                            .scaleEffect(1.3)
                            .tint(.green)
                        Text("Analysiere Blatt...")
                            .font(.hostGrotesk(.subheadline, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                    .transition(.opacity)
                }

                if let error = classificationService.errorMessage {
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text(error)
                            .font(.hostGrotesk(.subheadline))
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)
                }

                if !classificationService.lastResults.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Erkannte Baumarten")
                            .font(.hostGrotesk(.subheadline, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)

                        ForEach(Array(classificationService.lastResults.enumerated()), id: \.element.id) { index, result in
                            LeafResultRow(result: result, rank: index + 1)
                                .overlay {
                                    if index == 0 {
                                        RoundedRectangle(cornerRadius: 20)
                                            .stroke(
                                                LinearGradient(
                                                    colors: [.green.opacity(0.5), .mint.opacity(0.2), .green.opacity(0.15)],
                                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                                ),
                                                lineWidth: 1.5
                                            )
                                    }
                                }
                                .padding(.horizontal)
                        }
                    }

                    HStack(spacing: 10) {
                        Image(systemName: "lightbulb.fill")
                            .foregroundStyle(.yellow)
                            .font(.hostGrotesk(.subheadline))
                        Text("Einzelnes Blatt auf hellem Hintergrund ergibt bessere Ergebnisse.")
                            .font(.hostGrotesk(.caption))
                            .foregroundStyle(.secondary)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal)

                    VStack(spacing: 10) {
                        Button {
                            showCamera = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "camera.fill")
                                    .font(.hostGrotesk(.body, weight: .semibold))
                                Text("Neues Foto")
                                    .font(.hostGrotesk(.body, weight: .semibold))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(
                                LinearGradient(colors: [.green, .green.opacity(0.85)],
                                               startPoint: .topLeading, endPoint: .bottomTrailing),
                                in: RoundedRectangle(cornerRadius: 25)
                            )
                            .shadow(color: .green.opacity(0.3), radius: 10, y: 5)
                        }
                        .buttonStyle(GlassPressStyle())

                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            HStack(spacing: 8) {
                                Image(systemName: "photo.on.rectangle")
                                    .font(.hostGrotesk(.body, weight: .semibold))
                                Text("Anderes Bild wählen")
                                    .font(.hostGrotesk(.body, weight: .semibold))
                            }
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 25))
                            .overlay(
                                RoundedRectangle(cornerRadius: 25)
                                    .stroke(LiquidGlass.highlightGradient, lineWidth: 0.5)
                            )
                        }
                        .buttonStyle(GlassPressStyle())
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
            }
            .padding(.top, 4)
            .padding(.bottom, 28)
        }
    }
}

struct LeafResultRow: View {
    let result: LeafClassificationResult
    let rank: Int
    @State private var appState = AppState.shared

    var body: some View {
        GlassCard(padding: 12, elevation: rank == 1 ? .medium : .low) {
            HStack(spacing: 12) {

                ZStack {
                    Circle()
                        .fill(
                            rank == 1
                                ? LinearGradient(colors: [.green, .green.opacity(0.7)],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing)
                                : LinearGradient(colors: [Color(.systemGray5), Color(.systemGray5)],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .frame(width: 36, height: 36)
                    if rank == 1 {
                        Image(systemName: "leaf.fill")
                            .font(.hostGrotesk(.subheadline))
                            .foregroundStyle(.white)
                    } else {
                        Text("\(rank)")
                            .font(.hostGrotesk(.subheadline, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(result.speciesGerman)
                        .font(.hostGrotesk(.body, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    if !result.speciesLatin.isEmpty {
                        Text(result.speciesLatin)
                            .font(.hostGrotesk(.caption))
                            .foregroundStyle(.secondary)
                            .italic()
                            .lineLimit(1)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(result.confidencePercent)%")
                        .font(.hostGrotesk(.title3, weight: .bold))
                        .foregroundStyle(confidenceColor)
                    HStack(spacing: 3) {
                        Image(systemName: result.confidenceLevel.icon)
                            .font(.hostGrotesk(.caption2))
                        Text(result.confidenceLevel.description)
                            .font(.hostGrotesk(.caption2))
                    }
                    .foregroundStyle(confidenceColor)
                }
            }
        }
        .onTapGesture {
            if rank == 1 {
                appState.searchText = result.speciesGerman
                appState.selectedTab = .map
            }
        }
    }

    private var confidenceColor: Color {
        switch result.confidenceLevel {
        case .high: return .green
        case .medium: return .orange
        case .low: return .red
        }
    }
}

struct LeafCameraView: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraDevice = .rear
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture, dismiss: dismiss)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onCapture: (UIImage) -> Void
        let dismiss: DismissAction

        init(onCapture: @escaping (UIImage) -> Void, dismiss: DismissAction) {
            self.onCapture = onCapture
            self.dismiss = dismiss
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                onCapture(image)
            }
            dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
        }
    }
}

#Preview {
    LeafScannerView()
}
