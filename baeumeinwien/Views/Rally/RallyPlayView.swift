import SwiftUI
import MapKit
import AVFoundation

struct RallyPlayView: View {
    let rally: Rally
    @Binding var progress: RallyProgress?
    let onExit: () -> Void

    @State private var locationService = LocationService.shared
    @State private var appState = AppState.shared
    @State private var targetTrees: [RallyTargetTree] = []
    @State private var selectedTree: RallyTargetTree?
    @State private var showCamera = false
    @State private var showLeaderboard = false
    @State private var showHerbarium = false
    @State private var isRefreshing = false
    @State private var capturedImage: UIImage?
    @State private var nearbyTree: RallyTargetTree?

    private let nearbyThreshold: Double = 50

    var body: some View {
        ZStack {

            Map {

                UserAnnotation()

                ForEach(targetTrees) { tree in
                    Annotation(tree.speciesGerman, coordinate: tree.coordinate) {
                        TreeMarker(
                            tree: tree,
                            isNearby: isTreeNearby(tree),
                            isCompleted: tree.isCompleted,
                            onTap: {
                                selectedTree = tree
                            }
                        )
                    }
                }
            }
            .mapStyle(.standard(elevation: .realistic))
            .mapControls {
                MapUserLocationButton()
                MapCompass()
            }
            .edgesIgnoringSafeArea(.all)

            VStack {

                headerCard

                Spacer()

                if let nearby = nearbyTree, !nearby.isCompleted {
                    nearbyTreeCard(tree: nearby)
                }

                bottomControls
            }
        }
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    onExit()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.hostGrotesk(.title2))
                        .foregroundStyle(.white)
                        .background(.ultraThinMaterial, in: Circle())
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showLeaderboard = true
                } label: {
                    Image(systemName: "list.number")
                        .font(.hostGrotesk(.title3))
                        .foregroundStyle(.white)
                        .padding(8)
                        .background(.ultraThinMaterial, in: Circle())
                }
            }
        }
        .sheet(isPresented: $showLeaderboard) {
            RallyLeaderboardView(rallyId: rally.id)
        }
        .sheet(isPresented: $showHerbarium) {
            HerbariumView()
        }
        .sheet(isPresented: $showCamera) {
            if let tree = selectedTree {
                TreeCameraView(
                    tree: tree,
                    onCapture: { image in
                        capturedImage = image
                        showCamera = false
                        Task {
                            await completeTree(tree, with: image)
                        }
                    },
                    onCancel: {
                        showCamera = false
                    }
                )
            }
        }
        .task {
            await loadTargetTrees()
        }
        .onChange(of: locationService.currentLocation) { _, _ in
            updateNearbyTree()
        }
    }

    private var headerCard: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(rally.name)
                        .font(.hostGrotesk(.headline, weight: .semibold))
                    Text("Code: \(rally.code)")
                        .font(.hostGrotesk(.caption))
                        .foregroundStyle(.secondary)
                }
                Spacer()

                let remaining = targetTrees.filter { !$0.isCompleted }.count
                Text("\(remaining)")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(remaining == 0 ? .green : .orange)
                    .clipShape(Circle())
            }

            if let prog = progress {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("\(prog.speciesCollected) / \(prog.targetSpeciesCount ?? targetTrees.count) Bäume")
                            .font(.subheadline.bold())
                        Spacer()
                        Text("\(Int(prog.progressPercent))%")
                            .font(.hostGrotesk(.caption))
                            .foregroundStyle(.secondary)
                    }

                    ProgressView(value: prog.progressPercent, total: 100)
                        .tint(.green)
                }

                if prog.isCompleted {
                    HStack {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                        Text("Alle Bäume gefunden! 🎉")
                            .font(.hostGrotesk(.headline, weight: .semibold))
                            .foregroundStyle(.green)
                    }
                    .padding(.top, 4)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding()
    }

    private func nearbyTreeCard(tree: RallyTargetTree) -> some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "location.fill")
                    .foregroundStyle(.green)
                Text("Baum in der Nähe!")
                    .font(.hostGrotesk(.headline, weight: .semibold))
                Spacer()
            }

            HStack {
                Image(systemName: "tree.fill")
                    .font(.hostGrotesk(.title))
                    .foregroundStyle(.green)

                VStack(alignment: .leading) {
                    Text(tree.speciesGerman)
                        .font(.subheadline.bold())
                    if let distance = distanceToTree(tree) {
                        Text("\(Int(distance))m entfernt")
                            .font(.hostGrotesk(.caption))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Button {
                    selectedTree = tree
                    showCamera = true
                } label: {
                    Label("Fotografieren", systemImage: "camera.fill")
                        .font(.subheadline.bold())
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .foregroundStyle(.white)
                        .background(.green)
                        .clipShape(Capsule())
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.spring(), value: nearbyTree?.id)
    }

    private var bottomControls: some View {
        HStack(spacing: 16) {

            Button {
                showHerbarium = true
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "leaf.fill")
                        .font(.hostGrotesk(.title2))
                    Text("Herbarium")
                        .font(.hostGrotesk(.caption))
                }
                .frame(maxWidth: .infinity)
                .padding()
                .foregroundStyle(.white)
                .background(.green)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Button {
                Task {
                    await refreshProgress()
                }
            } label: {
                VStack(spacing: 4) {
                    if isRefreshing {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.hostGrotesk(.title2))
                    }
                    Text("Aktualisieren")
                        .font(.hostGrotesk(.caption))
                }
                .frame(maxWidth: .infinity)
                .padding()
                .foregroundStyle(.white)
                .background(.blue)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(isRefreshing)
        }
        .padding()
    }

    private func isTreeNearby(_ tree: RallyTargetTree) -> Bool {
        guard let distance = distanceToTree(tree) else { return false }
        return distance <= nearbyThreshold
    }

    private func distanceToTree(_ tree: RallyTargetTree) -> Double? {
        guard let userLocation = locationService.currentLocation else { return nil }
        let treeLocation = CLLocation(latitude: tree.latitude, longitude: tree.longitude)
        return userLocation.distance(from: treeLocation)
    }

    private func updateNearbyTree() {

        let nearby = targetTrees
            .filter { !$0.isCompleted }
            .compactMap { tree -> (tree: RallyTargetTree, distance: Double)? in
                guard let distance = distanceToTree(tree), distance <= nearbyThreshold else { return nil }
                return (tree, distance)
            }
            .sorted { $0.distance < $1.distance }
            .first?.tree

        withAnimation {
            nearbyTree = nearby
        }
    }

    private func loadTargetTrees() async {

        if let treeIds = rally.targetTreeIds, !treeIds.isEmpty {
            print("RallyPlayView: Loading \(treeIds.count) trees from rally.targetTreeIds")

            do {

                let trees = try await WFSService.shared.fetchTreesByIds(treeIds)

                if !trees.isEmpty {
                    print("RallyPlayView: Successfully loaded \(trees.count) trees from WFSService")
                    targetTrees = trees.map { tree in
                        RallyTargetTree(
                            id: tree.id,
                            speciesGerman: tree.speciesGerman,
                            speciesLatin: tree.speciesLatin,
                            latitude: tree.latitude,
                            longitude: tree.longitude,
                            isCompleted: false
                        )
                    }
                    updateNearbyTree()
                    return
                } else {
                    print("RallyPlayView: No trees found in local DB, trying fallback...")
                }
            } catch {
                print("RallyPlayView: Error loading trees: \(error)")
            }
        }

        let savedTreeIds = UserDefaults.standard.stringArray(forKey: "rally_trees_\(rally.id)") ?? []

        if !savedTreeIds.isEmpty {
            print("RallyPlayView: Loading \(savedTreeIds.count) trees from UserDefaults")
            do {
                let trees = try await WFSService.shared.fetchTreesByIds(savedTreeIds)
                targetTrees = trees.map { tree in
                    RallyTargetTree(
                        id: tree.id,
                        speciesGerman: tree.speciesGerman,
                        speciesLatin: tree.speciesLatin,
                        latitude: tree.latitude,
                        longitude: tree.longitude,
                        isCompleted: false
                    )
                }
                updateNearbyTree()
                return
            } catch {
                print("RallyPlayView: Error loading trees from UserDefaults IDs: \(error)")
            }
        }

        if let centerLat = rally.centerLat, let centerLng = rally.centerLng {
            print("RallyPlayView: Loading trees from rally center location")
            let centerCoord = CLLocationCoordinate2D(latitude: centerLat, longitude: centerLng)
            let radius = Double(rally.radiusMeters ?? 500)

            do {
                let trees = try await WFSService.shared.fetchTrees(around: centerCoord, radius: radius)

                targetTrees = trees.prefix(10).map { tree in
                    RallyTargetTree(
                        id: tree.id,
                        speciesGerman: tree.speciesGerman,
                        speciesLatin: tree.speciesLatin,
                        latitude: tree.latitude,
                        longitude: tree.longitude,
                        isCompleted: false
                    )
                }
                print("RallyPlayView: Loaded \(targetTrees.count) nearby trees as targets")
            } catch {
                print("RallyPlayView: Error loading nearby trees: \(error)")
            }
        }

        updateNearbyTree()
    }

    private func refreshProgress() async {
        isRefreshing = true

        let result = await SupabaseService.shared.getRallyProgress(rallyId: rally.id)

        await MainActor.run {
            isRefreshing = false

            if let newProgress = result.value {
                progress = newProgress
            }
        }
    }

    private func completeTree(_ tree: RallyTargetTree, with image: UIImage) async {

        if let index = targetTrees.firstIndex(where: { $0.id == tree.id }) {
            targetTrees[index].isCompleted = true
        }

        let entry = HerbariumEntry(
            id: UUID().uuidString,
            treeId: tree.id,
            speciesGerman: tree.speciesGerman,
            speciesLatin: tree.speciesLatin,
            photoData: image.jpegData(compressionQuality: 0.8),
            capturedAt: Date(),
            latitude: tree.latitude,
            longitude: tree.longitude,
            rallyId: rally.id
        )
        appState.herbariumEntries.append(entry)

        updateNearbyTree()

        await refreshProgress()
    }
}

struct RallyTargetTree: Identifiable {
    let id: String
    let speciesGerman: String
    let speciesLatin: String
    let latitude: Double
    let longitude: Double
    var isCompleted: Bool

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

struct TreeMarker: View {
    let tree: RallyTargetTree
    let isNearby: Bool
    let isCompleted: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                Circle()
                    .fill(markerColor)
                    .frame(width: 44, height: 44)
                    .shadow(radius: isNearby ? 8 : 4)

                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                } else {
                    Image(systemName: "tree.fill")
                        .font(.hostGrotesk(.title3))
                        .foregroundStyle(.white)
                }
            }
            .scaleEffect(isNearby ? 1.2 : 1.0)
            .animation(.spring(), value: isNearby)
        }
    }

    private var markerColor: Color {
        if isCompleted {
            return .green
        } else if isNearby {
            return .orange
        } else {
            return .blue
        }
    }
}

struct TreeCameraView: View {
    let tree: RallyTargetTree
    let onCapture: (UIImage) -> Void
    let onCancel: () -> Void

    @State private var showImagePicker = false
    @State private var capturedImage: UIImage?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {

                VStack(spacing: 8) {
                    Image(systemName: "tree.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.green)

                    Text(tree.speciesGerman)
                        .font(.title2.bold())

                    Text(tree.speciesLatin)
                        .font(.hostGrotesk(.subheadline))
                        .italic()
                        .foregroundStyle(.secondary)
                }

                Divider()

                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "camera.fill")
                            .foregroundStyle(.green)
                        Text("Fotografiere den Baum oder ein Blatt")
                            .font(.hostGrotesk(.headline, weight: .semibold))
                    }

                    Text("Das Foto wird in deinem digitalen Herbarium gespeichert")
                        .font(.hostGrotesk(.caption))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Spacer()

                if let image = capturedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    HStack(spacing: 16) {
                        Button("Neu aufnehmen") {
                            capturedImage = nil
                            showImagePicker = true
                        }
                        .buttonStyle(.bordered)

                        Button("Bestätigen") {
                            onCapture(image)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                    }
                } else {
                    Button {
                        showImagePicker = true
                    } label: {
                        Label("Kamera öffnen", systemImage: "camera.fill")
                            .font(.hostGrotesk(.headline, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.green)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Baum fotografieren")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        onCancel()
                    }
                }
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(image: $capturedImage)
            }
        }
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

#Preview {
    RallyPlayView(
        rally: Rally(
            id: "1",
            code: "ABC123",
            name: "Test Rally",
            description: nil,
            creatorId: "user1",
            creatorPlatform: "ios",
            mode: .student,
            status: .active,
            maxParticipants: 50,
            targetSpeciesCount: 5,
            timeLimitMinutes: nil,
            districtFilter: nil,
            radiusMeters: 500,
            targetTreeIds: nil,
            centerLat: 48.2082,
            centerLng: 16.3738,
            createdAt: Date(),
            startedAt: nil,
            endedAt: nil,
            isPublic: false,
            allowJoinAfterStart: true
        ),
        progress: .constant(nil),
        onExit: {}
    )
}
