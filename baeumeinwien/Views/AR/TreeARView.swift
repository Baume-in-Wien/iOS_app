import SwiftUI
import ARKit
import RealityKit
import CoreLocation

struct TreeARView: View {
    @State private var appState = AppState.shared
    @State private var nearbyTrees: [Tree] = []
    @State private var message: String = "Suche nach Bäumen..."
    @State private var lastUpdateLocation: CLLocation?
    @State private var showSafetyWarning = true
    @State private var selectedARTree: Tree? = nil

    var body: some View {
        ZStack {
            ARViewContainer(nearbyTrees: $nearbyTrees, selectedTree: $selectedARTree)
                .edgesIgnoringSafeArea(.all)

            VStack {

                HStack {
                    VStack(alignment: .leading) {
                        Text("AR Modus (Beta)")
                            .font(.title2.bold())
                            .foregroundStyle(.white)

                        Text("\(nearbyTrees.count) Bäume in der Nähe")
                            .font(.hostGrotesk(.subheadline))
                            .foregroundStyle(.white.opacity(0.8))
                    }

                    Spacer()

                    if !message.isEmpty {
                        Text(message)
                            .font(.hostGrotesk(.caption))
                            .padding(8)
                            .background(.ultraThinMaterial, in: Capsule())
                    }
                }
                .padding()
                .background(
                    LinearGradient(
                        colors: [.black.opacity(0.6), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                Spacer()

                if let tree = selectedARTree {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(tree.speciesGerman)
                                .font(.hostGrotesk(.headline, weight: .semibold))
                                .foregroundStyle(.primary)
                            Spacer()
                            Button {
                                selectedARTree = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Text(tree.speciesLatin)
                            .font(.hostGrotesk(.subheadline))
                            .foregroundStyle(.secondary)
                            .italic()
                        HStack(spacing: 16) {
                            if let height = tree.height {
                                Label("\(String(format: "%.1f", height)) m", systemImage: "arrow.up.to.line")
                                    .font(.hostGrotesk(.caption))
                            }
                            if let year = tree.yearPlanted {
                                Label("Gepflanzt \(year)", systemImage: "calendar")
                                    .font(.hostGrotesk(.caption))
                            }
                        }
                        .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }

                Text("Halte dein Gerät hoch und schau dich um, um Bäume zu entdecken.")
                    .font(.hostGrotesk(.caption))
                    .foregroundStyle(.white)
                    .padding()
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.bottom, 50)
            }
        }
        .alert("⚠️ Sicherheitshinweis", isPresented: $showSafetyWarning) {
            Button("Verstanden") {
                showSafetyWarning = false
            }
        } message: {
            Text("Bitte achte immer auf deine Umgebung und den Straßenverkehr! Bleib auf dem Gehweg und schaue regelmäßig vom Bildschirm auf. Deine Sicherheit geht vor.")
        }
        .onAppear {
            LocationService.shared.startTracking()
            loadNearbyTrees()
        }
        .onChange(of: LocationService.shared.currentLocation) { _, newLocation in
            guard let newLocation else { return }

            if nearbyTrees.isEmpty {
                loadNearbyTrees()
                return
            }

            if let lastLocation = lastUpdateLocation, newLocation.distance(from: lastLocation) > 10 {
                loadNearbyTrees()
            }
        }
    }

    private func loadNearbyTrees() {
        guard let location = LocationService.shared.currentLocation else {
            message = "Standort nicht verfügbar"
            return
        }

        lastUpdateLocation = location

        Task {
            do {

                let trees = try await WFSService.shared.fetchTrees(around: location.coordinate, radius: 100)

                let sortedTrees = trees.sorted { t1, t2 in
                    let loc1 = CLLocation(latitude: t1.latitude, longitude: t1.longitude)
                    let loc2 = CLLocation(latitude: t2.latitude, longitude: t2.longitude)
                    return location.distance(from: loc1) < location.distance(from: loc2)
                }

                await MainActor.run {

                    self.nearbyTrees = Array(sortedTrees.prefix(20))
                    self.message = sortedTrees.isEmpty ? "Keine Bäume in der Nähe gefunden" : ""
                }
            } catch {
                print("Error loading AR trees: \(error)")
                await MainActor.run {
                    self.message = "Fehler beim Laden der Bäume"
                }
            }
        }
    }
}

struct ARViewContainer: UIViewRepresentable {
    @Binding var nearbyTrees: [Tree]
    @Binding var selectedTree: Tree?

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)

        let config = ARWorldTrackingConfiguration()
        config.worldAlignment = .gravityAndHeading
        config.planeDetection = [.horizontal]

        if !ARWorldTrackingConfiguration.isSupported {
            print("AR is not supported on this device")
        }

        arView.session.run(config)

        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        arView.addGestureRecognizer(tapGesture)

        context.coordinator.arView = arView

        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {

        context.coordinator.trees = nearbyTrees

        uiView.scene.anchors.removeAll()

        guard let userLocation = LocationService.shared.currentLocation else { return }

        for tree in nearbyTrees {

            let bearing = getBearing(from: userLocation.coordinate, to: CLLocationCoordinate2D(latitude: tree.latitude, longitude: tree.longitude))
            let distance = userLocation.distance(from: CLLocation(latitude: tree.latitude, longitude: tree.longitude))

            if distance > 2 && distance < 100 {
                let position = positionFrom(bearing: bearing, distance: distance)

                let anchor = AnchorEntity(world: position)
                anchor.name = tree.id

                let baseRadius: Float = 0.2
                let maxRadius: Float = 1.2
                let scaleFactor = Float(1.0 - min(distance / 100.0, 1.0))
                let sphereRadius = baseRadius + (maxRadius - baseRadius) * scaleFactor

                let mesh = MeshResource.generateSphere(radius: sphereRadius)
                let color = uiColor(from: tree.speciesColor)
                let material = SimpleMaterial(color: color, isMetallic: false)
                let model = ModelEntity(mesh: mesh, materials: [material])
                model.name = tree.id
                model.generateCollisionShapes(recursive: true)

                let textSize: CGFloat = CGFloat(0.15 + 0.35 * scaleFactor)

                let textMesh = MeshResource.generateText(
                    tree.speciesGerman,
                    extrusionDepth: 0.02,
                    font: .systemFont(ofSize: textSize, weight: .bold),
                    containerFrame: .zero,
                    alignment: .center,
                    lineBreakMode: .byWordWrapping
                )
                let textMaterial = SimpleMaterial(color: .white, isMetallic: false)
                let textModel = ModelEntity(mesh: textMesh, materials: [textMaterial])
                textModel.position = [0, sphereRadius + 0.3, 0]

                textModel.look(at: .zero, from: textModel.position, relativeTo: nil)

                anchor.addChild(model)
                anchor.addChild(textModel)

                uiView.scene.addAnchor(anchor)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject {
        var parent: ARViewContainer
        var arView: ARView?
        var trees: [Tree] = []

        init(_ parent: ARViewContainer) {
            self.parent = parent
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let arView = arView else { return }
            let location = gesture.location(in: arView)

            if let entity = arView.entity(at: location) {

                let treeId = entity.name
                if let tree = trees.first(where: { $0.id == treeId }) {
                    DispatchQueue.main.async {
                        self.parent.selectedTree = tree
                    }
                }
            }
        }
    }

    private func uiColor(from string: String) -> UIColor {
        switch string {
        case "green": return .green
        case "orange": return .orange
        case "brown": return .brown
        case "red": return .red
        case "mint": return .cyan
        case "teal": return .systemTeal
        default: return .systemGreen
        }
    }

    private func getBearing(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let lat1 = from.latitude * .pi / 180
        let lon1 = from.longitude * .pi / 180
        let lat2 = to.latitude * .pi / 180
        let lon2 = to.longitude * .pi / 180

        let dLon = lon2 - lon1
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let radiansBearing = atan2(y, x)

        return radiansBearing
    }

    private func positionFrom(bearing: Double, distance: Double) -> SIMD3<Float> {

        let x = Float(distance * sin(bearing))
        let z = Float(-distance * cos(bearing))
        return SIMD3<Float>(x, 0, z)
    }
}

#Preview {
    TreeARView()
}
