import SwiftUI
import MapKit

struct TreeMapView: View {
    @State private var appState = AppState.shared
    @State private var authService = AuthService.shared
    @State private var locationService = LocationService.shared
    @State private var showSearch = false
    @State private var showAddTree = false
    @State private var showLogin = false
    @State private var selectedCommunityTree: CommunityTree?
    @State private var isLoadingTrees = false
    @State private var treeCount = 0
    @State private var isZoomedOut = false
    @State private var loadTask: Task<Void, Never>?
    @State private var communityLoadTask: Task<Void, Never>?
    @State private var clusters: [DistrictCluster] = []

    @State private var disableClustering = false

    @State private var is3DMode = false

    private var highlightedTreeIDs: Set<String> {
        if let id = appState.highlightedTreeID {
            return Set([id])
        }
        return Set()
    }

    var body: some View {
        NavigationStack {
            ZStack {

                TreeMapViewWrapper(
                    trees: appState.trees,
                    communityTrees: appState.communityTrees,
                    clusters: clusters,
                    selectedTree: $appState.selectedTree,
                    selectedCommunityTree: $selectedCommunityTree,
                    region: $appState.mapRegion,
                    onRegionChange: { region in
                        loadTreesForRegion(region)
                        loadCommunityTreesForRegion(region)
                    },
                    highlightedTreeIDs: highlightedTreeIDs,
                    disableClustering: disableClustering,
                    is3DMode: is3DMode
                )
                .edgesIgnoringSafeArea(.all)

                floatingControls

                if isLoadingTrees {
                    loadingOverlay
                }

                if treeCount > 0 && !isLoadingTrees {
                    treeCountBadge
                }

                if isZoomedOut {
                    zoomMessage
                }
            }
            .navigationTitle("Bäume in Wien")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .sheet(item: $appState.selectedTree) { tree in
                TreeDetailSheet(tree: tree)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(24)
            }
            .onChange(of: appState.selectedTree) { oldValue, newValue in

                if newValue == nil && oldValue != nil {
                    appState.highlightedTreeID = nil
                }
            }
            .sheet(isPresented: $showSearch) {
                TreeSearchView()
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(.ultraThinMaterial)
                    .presentationCornerRadius(24)
            }
            .sheet(item: $selectedCommunityTree) { communityTree in
                CommunityTreeDetailSheet(tree: communityTree)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(24)
            }
            .sheet(isPresented: $showAddTree) {
                AddTreeView()
            }
            .sheet(isPresented: $showLogin) {
                LoginView()
            }
        }
        .onAppear {
            locationService.requestAuthorization()

            loadTreesForRegion(appState.mapRegion)
            loadCommunityTreesForRegion(appState.mapRegion)
        }
        .onChange(of: showAddTree) { _, isShowing in
            if !isShowing {

                loadCommunityTreesForRegion(appState.mapRegion)
            }
        }
    }

    private var floatingControls: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                VStack(spacing: 12) {

                    Button {
                        is3DMode.toggle()
                    } label: {
                        Image(systemName: is3DMode ? "view.3d" : "map")
                            .font(.hostGrotesk(.title3))
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)
                            .frame(width: 48, height: 48)
                            .background(.regularMaterial, in: Circle())
                            .overlay(
                                Circle()
                                    .stroke(
                                        LinearGradient(
                                            colors: [.white.opacity(0.4), .white.opacity(0.1)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 0.5
                                    )
                            )
                            .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 6)
                    }

                    Button {
                        loadTreesForRegion(appState.mapRegion)
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.hostGrotesk(.title3))
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)
                            .frame(width: 48, height: 48)
                            .background(.regularMaterial, in: Circle())
                            .overlay(
                                Circle()
                                    .stroke(
                                        LinearGradient(
                                            colors: [.white.opacity(0.4), .white.opacity(0.1)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 0.5
                                    )
                            )
                            .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 6)
                    }

                    Button {
                        centerOnUserLocation()
                    } label: {
                        Image(systemName: "location.fill")
                            .font(.hostGrotesk(.title3))
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)
                            .frame(width: 48, height: 48)
                            .background(.regularMaterial, in: Circle())
                            .overlay(
                                Circle()
                                    .stroke(
                                        LinearGradient(
                                            colors: [.white.opacity(0.4), .white.opacity(0.1)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 0.5
                                    )
                            )
                            .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 6)
                    }

                    Button {
                        if authService.authState.isAuthenticated {
                            showAddTree = true
                        } else {
                            showLogin = true
                        }
                    } label: {
                        Image(systemName: "plus")
                            .font(.hostGrotesk(.title2))
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .frame(width: 56, height: 56)
                            .background(
                                LinearGradient(
                                    colors: [.orange, .orange.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                in: Circle()
                            )
                            .overlay(
                                Circle()
                                    .stroke(.white.opacity(0.3), lineWidth: 1)
                            )
                            .shadow(color: .orange.opacity(0.4), radius: 12, x: 0, y: 6)
                    }

                    Button {
                        showSearch = true
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .font(.hostGrotesk(.title2))
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .frame(width: 56, height: 56)
                            .background(
                                LinearGradient(
                                    colors: [Color.accentColor, Color.accentColor.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                in: Circle()
                            )
                            .overlay(
                                Circle()
                                    .stroke(.white.opacity(0.3), lineWidth: 1)
                            )
                            .shadow(color: .accentColor.opacity(0.4), radius: 12, x: 0, y: 6)
                    }
                }
                .padding(.trailing, 16)
                .padding(.bottom, 100)
            }
        }
    }

    private var loadingOverlay: some View {
        VStack {
            VStack(spacing: 12) {
                ProgressView()
                    .scaleEffect(1.2)
                    .tint(.accentColor)

                Text("Lade Bäume...")
                    .font(.hostGrotesk(.subheadline))
                    .foregroundStyle(.secondary)
            }
            .padding(20)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.4), .white.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            )
            .shadow(color: .black.opacity(0.15), radius: 20, y: 10)

            Spacer()
        }
        .padding(.top, 100)
    }

    private var treeCountBadge: some View {
        VStack {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "tree.fill")
                        .font(.hostGrotesk(.caption))
                        .foregroundStyle(.green)

                    Text("\(treeCount) Bäume")
                        .font(.hostGrotesk(.caption))
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(.white.opacity(0.2), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.1), radius: 8, y: 4)

                Spacer()
            }
            .padding(.leading, 16)
            .padding(.top, 8)

            Spacer()
        }
    }

    private var zoomMessage: some View {
        VStack {
            HStack(spacing: 8) {
                Image(systemName: "plus.magnifyingglass")
                    .font(.hostGrotesk())
                Text("Bitte hineinzoomen")
                    .font(.hostGrotesk(.subheadline))
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.regularMaterial, in: Capsule())
            .overlay(
                Capsule()
                    .stroke(.white.opacity(0.3), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
            .padding(.top, 16)

            Spacer()
        }
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private func loadTreesForRegion(_ region: MKCoordinateRegion) {
        loadTask?.cancel()
        loadTask = Task {

            try? await Task.sleep(nanoseconds: 400_000_000)
            if Task.isCancelled { return }

            let span = max(region.span.latitudeDelta, region.span.longitudeDelta)

            let isTooZoomedOut = span > 0.03

            if isTooZoomedOut {
                await MainActor.run {
                    withAnimation {
                        isZoomedOut = true
                    }
                    if !appState.trees.isEmpty {
                        appState.trees = []
                        treeCount = 0
                    }
                }

                let newClusters = await WFSService.shared.getDistrictClusters()
                await MainActor.run {
                    self.clusters = newClusters
                }
                return
            } else {

                await MainActor.run {
                    withAnimation {
                        isZoomedOut = false
                    }
                    if !clusters.isEmpty {
                        clusters = []
                    }
                }
            }

            await MainActor.run {
                isLoadingTrees = true
            }

            do {

                let radius = span * 111320 / 2.0

                let trees = try await WFSService.shared.fetchTrees(
                    around: region.center,
                    radius: radius
                )

                if Task.isCancelled { return }

                await MainActor.run {

                    let safeLimit: Int
                    if span < 0.002 {
                        safeLimit = 500
                        disableClustering = true
                    } else if span < 0.005 {
                        safeLimit = 800
                        disableClustering = true
                    } else if span < 0.01 {
                        safeLimit = 1200
                        disableClustering = false
                    } else {
                        safeLimit = 1500
                        disableClustering = false
                    }

                    if trees.count > safeLimit {

                        let step = trees.count / safeLimit
                        var sampled: [Tree] = []
                        for i in stride(from: 0, to: trees.count, by: max(1, step)) {
                            sampled.append(trees[i])
                        }
                        appState.trees = sampled
                    } else {
                        appState.trees = trees
                    }

                    treeCount = trees.count
                    isLoadingTrees = false
                }
            } catch {
                print("Failed to load trees: \(error)")
                await MainActor.run {
                    isLoadingTrees = false
                }
            }
        }
    }

    private func loadCommunityTreesForRegion(_ region: MKCoordinateRegion) {
        communityLoadTask?.cancel()
        communityLoadTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            if Task.isCancelled { return }

            let span = region.span
            let minLat = region.center.latitude - span.latitudeDelta / 2
            let maxLat = region.center.latitude + span.latitudeDelta / 2
            let minLon = region.center.longitude - span.longitudeDelta / 2
            let maxLon = region.center.longitude + span.longitudeDelta / 2

            let trees = await CommunityTreeService.shared.getCommunityTreesInBounds(
                minLat: minLat, maxLat: maxLat,
                minLon: minLon, maxLon: maxLon
            )

            if Task.isCancelled { return }

            await MainActor.run {
                appState.communityTrees = trees
            }
        }
    }

    private func centerOnUserLocation() {
        Task {
            if let location = await locationService.getCurrentLocation() {
                await MainActor.run {
                    appState.mapRegion = MKCoordinateRegion(
                        center: location.coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.002, longitudeDelta: 0.002)
                    )
                }
            }
        }
    }
}

struct TreeMapViewWrapper: UIViewRepresentable {
    var trees: [Tree]
    var communityTrees: [CommunityTree]
    var clusters: [DistrictCluster]
    @Binding var selectedTree: Tree?
    @Binding var selectedCommunityTree: CommunityTree?
    @Binding var region: MKCoordinateRegion
    var onRegionChange: (MKCoordinateRegion) -> Void
    var highlightedTreeIDs: Set<String> = []
    var disableClustering: Bool = false
    var is3DMode: Bool = false

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.showsCompass = true
        mapView.showsScale = true
        mapView.showsBuildings = true
        mapView.mapType = is3DMode ? .hybridFlyover : .standard
        mapView.isPitchEnabled = true
        mapView.isRotateEnabled = true

        mapView.pointOfInterestFilter = .excludingAll

        mapView.register(TreeMarkerAnnotationView.self, forAnnotationViewWithReuseIdentifier: MKMapViewDefaultAnnotationViewReuseIdentifier)
        mapView.register(TreeClusterAnnotationView.self, forAnnotationViewWithReuseIdentifier: MKMapViewDefaultClusterAnnotationViewReuseIdentifier)
        mapView.register(DistrictAnnotationView.self, forAnnotationViewWithReuseIdentifier: "DistrictCluster")
        mapView.register(NonClusteringTreeAnnotationView.self, forAnnotationViewWithReuseIdentifier: "NonClusteringTree")
        mapView.register(HighlightedTreeAnnotationView.self, forAnnotationViewWithReuseIdentifier: "HighlightedTree")
        mapView.register(CommunityTreeAnnotationView.self, forAnnotationViewWithReuseIdentifier: "CommunityTree")

        mapView.setRegion(region, animated: false)

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {

        let targetMapType: MKMapType = is3DMode ? .hybridFlyover : .standard
        if mapView.mapType != targetMapType {
            mapView.mapType = targetMapType
            mapView.showsBuildings = true

            if is3DMode {
                let camera = MKMapCamera(
                    lookingAtCenter: mapView.centerCoordinate,
                    fromDistance: mapView.camera.centerCoordinateDistance,
                    pitch: 60,
                    heading: mapView.camera.heading
                )
                mapView.setCamera(camera, animated: true)
            } else {

                let camera = MKMapCamera(
                    lookingAtCenter: mapView.centerCoordinate,
                    fromDistance: mapView.camera.centerCoordinateDistance,
                    pitch: 0,
                    heading: 0
                )
                mapView.setCamera(camera, animated: true)
            }
        }

        context.coordinator.highlightedTreeIDs = highlightedTreeIDs

        let currentRegion = mapView.region
        let latDiff = abs(currentRegion.center.latitude - region.center.latitude)
        let lonDiff = abs(currentRegion.center.longitude - region.center.longitude)
        let spanLatDiff = abs(currentRegion.span.latitudeDelta - region.span.latitudeDelta)

        let lastRegion = context.coordinator.lastProgrammaticRegion
        let isNewProgrammaticRegion = abs(lastRegion.center.latitude - region.center.latitude) > 0.0001 ||
                                       abs(lastRegion.center.longitude - region.center.longitude) > 0.0001 ||
                                       abs(lastRegion.span.latitudeDelta - region.span.latitudeDelta) > 0.001

        if isNewProgrammaticRegion && (latDiff > 0.001 || lonDiff > 0.001 || spanLatDiff > 0.005) {
            context.coordinator.isProgrammaticChange = true
            context.coordinator.lastProgrammaticRegion = region
            mapView.setRegion(region, animated: true)
        }

        let currentTreeAnnotations = mapView.annotations.compactMap { $0 as? TreeAnnotation }
        let currentDistrictAnnotations = mapView.annotations.compactMap { $0 as? DistrictAnnotation }

        if !clusters.isEmpty {

            if !currentTreeAnnotations.isEmpty {
                mapView.removeAnnotations(currentTreeAnnotations)
            }

            let currentClusterIds = Set(currentDistrictAnnotations.map { $0.cluster.id })
            let newClusterIds = Set(clusters.map { $0.id })

            let clustersToRemove = currentDistrictAnnotations.filter { !newClusterIds.contains($0.cluster.id) }
            if !clustersToRemove.isEmpty {
                mapView.removeAnnotations(clustersToRemove)
            }

            let clustersToAdd = clusters.filter { !currentClusterIds.contains($0.id) }.map { DistrictAnnotation(cluster: $0) }
            if !clustersToAdd.isEmpty {
                mapView.addAnnotations(clustersToAdd)
            }
        } else {

            if !currentDistrictAnnotations.isEmpty {
                mapView.removeAnnotations(currentDistrictAnnotations)
            }

            let currentIds = Set(currentTreeAnnotations.map { $0.tree.id })
            let newIds = Set(trees.map { $0.id })

            let highlightedInCurrent = currentTreeAnnotations.filter { highlightedTreeIDs.contains($0.tree.id) }
            let highlightedNeedingRefresh = highlightedInCurrent.filter { annotation in

                let existingView = mapView.view(for: annotation)
                return !(existingView is HighlightedTreeAnnotationView)
            }

            let nonHighlightedNeedingRefresh = currentTreeAnnotations.filter { annotation in
                !highlightedTreeIDs.contains(annotation.tree.id) &&
                mapView.view(for: annotation) is HighlightedTreeAnnotationView
            }

            var toRemove = currentTreeAnnotations.filter { !newIds.contains($0.tree.id) }
            toRemove.append(contentsOf: highlightedNeedingRefresh)
            toRemove.append(contentsOf: nonHighlightedNeedingRefresh)
            if !toRemove.isEmpty {
                mapView.removeAnnotations(toRemove)
            }

            let removedIds = Set(toRemove.map { $0.tree.id })
            let idsToSkip = currentIds.subtracting(removedIds)

            let toAdd = trees.filter { !idsToSkip.contains($0.id) }.map { tree in
                let annotation = TreeAnnotation(tree: tree)

                annotation.shouldCluster = !disableClustering && !highlightedTreeIDs.contains(tree.id)
                return annotation
            }
            if !toAdd.isEmpty {
                mapView.addAnnotations(toAdd)
            }

            context.coordinator.disableClustering = disableClustering
        }

        let currentCommunityAnnotations = mapView.annotations.compactMap { $0 as? CommunityTreeAnnotation }
        let currentCommunityIds = Set(currentCommunityAnnotations.map { $0.communityTree.id })
        let newCommunityIds = Set(communityTrees.map { $0.id })

        let communityToRemove = currentCommunityAnnotations.filter { !newCommunityIds.contains($0.communityTree.id) }
        if !communityToRemove.isEmpty {
            mapView.removeAnnotations(communityToRemove)
        }

        let communityToAdd = communityTrees.filter { !currentCommunityIds.contains($0.id) }.map { CommunityTreeAnnotation(communityTree: $0) }
        if !communityToAdd.isEmpty {
            mapView.addAnnotations(communityToAdd)
        }

        if let selected = selectedTree {
            let selectedAnnotation = mapView.selectedAnnotations.first as? TreeAnnotation
            if selectedAnnotation?.tree.id != selected.id {
                if let annotation = mapView.annotations.first(where: { ($0 as? TreeAnnotation)?.tree.id == selected.id }) {
                    mapView.selectAnnotation(annotation, animated: true)
                }
            }
        } else {
            if !mapView.selectedAnnotations.isEmpty {
                mapView.deselectAnnotation(mapView.selectedAnnotations.first, animated: true)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: TreeMapViewWrapper
        var isProgrammaticChange = false
        var lastProgrammaticRegion = MKCoordinateRegion()
        var disableClustering = false
        var highlightedTreeIDs: Set<String> = []

        init(_ parent: TreeMapViewWrapper) {
            self.parent = parent
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {

            if isProgrammaticChange {
                isProgrammaticChange = false
                return
            }

            DispatchQueue.main.async {
                self.parent.region = mapView.region
                self.parent.onRegionChange(mapView.region)
            }
        }

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            if let treeAnnotation = view.annotation as? TreeAnnotation {
                parent.selectedTree = treeAnnotation.tree
            }
            if let communityAnnotation = view.annotation as? CommunityTreeAnnotation {
                parent.selectedCommunityTree = communityAnnotation.communityTree
            }

            if let districtAnnotation = view.annotation as? DistrictAnnotation {
                let region = MKCoordinateRegion(center: districtAnnotation.coordinate, span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05))
                mapView.setRegion(region, animated: true)
            }
        }

        func mapView(_ mapView: MKMapView, didDeselect view: MKAnnotationView) {
            if view.annotation is TreeAnnotation {
                parent.selectedTree = nil
            }
            if view.annotation is CommunityTreeAnnotation {
                parent.selectedCommunityTree = nil
            }
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is DistrictAnnotation {
                return mapView.dequeueReusableAnnotationView(withIdentifier: "DistrictCluster", for: annotation)
            }

            if annotation is CommunityTreeAnnotation {
                return mapView.dequeueReusableAnnotationView(withIdentifier: "CommunityTree", for: annotation)
            }

            if let treeAnnotation = annotation as? TreeAnnotation {
                let isHighlighted = highlightedTreeIDs.contains(treeAnnotation.tree.id)

                if isHighlighted {

                    let view = mapView.dequeueReusableAnnotationView(withIdentifier: "HighlightedTree", for: annotation) as? HighlightedTreeAnnotationView
                        ?? HighlightedTreeAnnotationView(annotation: annotation, reuseIdentifier: "HighlightedTree")
                    view.annotation = annotation
                    return view
                }

                if !treeAnnotation.shouldCluster {
                    return mapView.dequeueReusableAnnotationView(withIdentifier: "NonClusteringTree", for: annotation)
                }
            }

            return nil
        }
    }
}

class DistrictAnnotation: MKPointAnnotation {
    let cluster: DistrictCluster

    init(cluster: DistrictCluster) {
        self.cluster = cluster
        super.init()
        self.coordinate = cluster.coordinate
        self.title = "\(cluster.count) Bäume"
    }
}

class DistrictAnnotationView: MKAnnotationView {
    override var annotation: MKAnnotation? {
        didSet { configure() }
    }

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        configure()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure() {
        guard let districtAnnotation = annotation as? DistrictAnnotation else { return }

        frame = CGRect(x: 0, y: 0, width: 60, height: 60)
        backgroundColor = .systemGreen
        layer.cornerRadius = 30
        layer.borderWidth = 2
        layer.borderColor = UIColor.white.cgColor

        let label = UILabel(frame: bounds)
        label.text = "\(districtAnnotation.cluster.count)"
        label.textColor = .white
        label.textAlignment = .center
        label.font = .boldSystemFont(ofSize: 12)
        label.adjustsFontSizeToFitWidth = true

        subviews.forEach { $0.removeFromSuperview() }
        addSubview(label)
    }
}

class TreeAnnotation: MKPointAnnotation {
    let tree: Tree
    var shouldCluster: Bool = true

    init(tree: Tree) {
        self.tree = tree
        super.init()
        self.coordinate = tree.coordinate
        self.title = tree.speciesGerman
    }
}

class TreeMarkerAnnotationView: MKMarkerAnnotationView {
    override var annotation: MKAnnotation? {
        didSet { configure() }
    }

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        clusteringIdentifier = "treeCluster"

        animatesWhenAdded = false
        canShowCallout = false

        collisionMode = .circle
        configure()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure() {
        guard annotation is TreeAnnotation else { return }

        markerTintColor = .systemGreen
        glyphImage = nil
        glyphText = nil

        displayPriority = .defaultHigh
    }
}

class TreeClusterAnnotationView: MKMarkerAnnotationView {
    override var annotation: MKAnnotation? {
        didSet { configure() }
    }

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        displayPriority = .defaultHigh
        collisionMode = .circle
        configure()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure() {
        guard let cluster = annotation as? MKClusterAnnotation else { return }

        let count = cluster.memberAnnotations.count
        markerTintColor = .systemGreen

        if count < 100 {
            glyphText = "\(count)"
            glyphImage = nil
        } else {
            glyphText = nil
            glyphImage = UIImage(systemName: "tree.fill")
        }
    }
}

class NonClusteringTreeAnnotationView: MKMarkerAnnotationView {
    override var annotation: MKAnnotation? {
        didSet { configure() }
    }

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)

        clusteringIdentifier = nil
        animatesWhenAdded = false
        canShowCallout = false
        configure()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure() {
        guard annotation is TreeAnnotation else { return }
        markerTintColor = .systemGreen
        glyphImage = nil
        glyphText = nil
        displayPriority = .required
    }
}

class HighlightedTreeAnnotationView: MKAnnotationView {
    private var pulseLayer: CAShapeLayer?
    private var glowLayer: CAShapeLayer?

    override var annotation: MKAnnotation? {
        didSet { configure() }
    }

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        clusteringIdentifier = nil
        configure()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure() {
        guard annotation is TreeAnnotation else { return }

        pulseLayer?.removeFromSuperlayer()
        glowLayer?.removeFromSuperlayer()
        subviews.forEach { $0.removeFromSuperview() }

        frame = CGRect(x: 0, y: 0, width: 60, height: 60)
        centerOffset = CGPoint(x: 0, y: -30)

        let pulseRing = CAShapeLayer()
        pulseRing.path = UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: 60, height: 60)).cgPath
        pulseRing.fillColor = UIColor.systemOrange.withAlphaComponent(0.2).cgColor
        pulseRing.strokeColor = UIColor.systemOrange.withAlphaComponent(0.6).cgColor
        pulseRing.lineWidth = 3
        layer.addSublayer(pulseRing)
        self.pulseLayer = pulseRing

        let glowRing = CAShapeLayer()
        glowRing.path = UIBezierPath(ovalIn: CGRect(x: 10, y: 10, width: 40, height: 40)).cgPath
        glowRing.fillColor = UIColor.systemOrange.withAlphaComponent(0.3).cgColor
        glowRing.strokeColor = UIColor.systemOrange.cgColor
        glowRing.lineWidth = 2
        layer.addSublayer(glowRing)
        self.glowLayer = glowRing

        let centerView = UIView(frame: CGRect(x: 15, y: 15, width: 30, height: 30))
        centerView.backgroundColor = .systemOrange
        centerView.layer.cornerRadius = 15
        centerView.layer.shadowColor = UIColor.systemOrange.cgColor
        centerView.layer.shadowRadius = 8
        centerView.layer.shadowOpacity = 0.8
        centerView.layer.shadowOffset = .zero
        addSubview(centerView)

        let iconView = UIImageView(image: UIImage(systemName: "tree.fill"))
        iconView.tintColor = .white
        iconView.frame = CGRect(x: 6, y: 5, width: 18, height: 20)
        iconView.contentMode = .scaleAspectFit
        centerView.addSubview(iconView)

        startPulseAnimation()

        displayPriority = .required
    }

    private func startPulseAnimation() {

        let scaleAnimation = CABasicAnimation(keyPath: "transform.scale")
        scaleAnimation.fromValue = 0.8
        scaleAnimation.toValue = 1.2
        scaleAnimation.duration = 1.0
        scaleAnimation.autoreverses = true
        scaleAnimation.repeatCount = .infinity
        scaleAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        let opacityAnimation = CABasicAnimation(keyPath: "opacity")
        opacityAnimation.fromValue = 0.8
        opacityAnimation.toValue = 0.3
        opacityAnimation.duration = 1.0
        opacityAnimation.autoreverses = true
        opacityAnimation.repeatCount = .infinity
        opacityAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        pulseLayer?.add(scaleAnimation, forKey: "pulse")
        pulseLayer?.add(opacityAnimation, forKey: "fade")
    }
}

class CommunityTreeAnnotation: MKPointAnnotation {
    let communityTree: CommunityTree

    init(communityTree: CommunityTree) {
        self.communityTree = communityTree
        super.init()
        self.coordinate = communityTree.coordinate
        self.title = communityTree.speciesGerman
    }
}

class CommunityTreeAnnotationView: MKMarkerAnnotationView {
    override var annotation: MKAnnotation? {
        didSet { configure() }
    }

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        clusteringIdentifier = nil
        animatesWhenAdded = false
        canShowCallout = true
        configure()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure() {
        guard let communityAnnotation = annotation as? CommunityTreeAnnotation else { return }
        let tree = communityAnnotation.communityTree

        if tree.isOfficialTree {
            markerTintColor = .systemBlue
            glyphImage = UIImage(systemName: "checkmark.seal.fill")
        } else if tree.status == "verified" {
            markerTintColor = .systemGreen
            glyphImage = UIImage(systemName: "checkmark.circle.fill")
        } else {
            markerTintColor = .systemOrange
            glyphImage = UIImage(systemName: "leaf.fill")
        }

        displayPriority = .defaultHigh
    }
}

#Preview {
    TreeMapView()
}
