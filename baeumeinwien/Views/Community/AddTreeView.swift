import SwiftUI
import MapKit
import CoreLocation
import PhotosUI

struct AddTreeView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var authService = AuthService.shared
    @State private var step: AddTreeStep = .gps
    @State private var latitude: Double?
    @State private var longitude: Double?
    @State private var gpsAccuracy: Double?
    @State private var locationMethod = "gps"
    @State private var selectedSpecies: TreeSpecies?
    @State private var speciesQuery = ""
    @State private var speciesResults: [TreeSpecies] = []
    @State private var isSearchingSpecies = false
    @State private var estimatedHeight = ""
    @State private var estimatedTrunkCircumference = ""
    @State private var isSubmitting = false
    @State private var submitSuccess = false
    @State private var errorMessage: String?
    @State private var searchTask: Task<Void, Never>?

    @State private var showLeafCamera = false
    @State private var leafScanPhotoItem: PhotosPickerItem?
    @State private var leafScanResults: [LeafClassificationResult] = []
    @State private var isClassifyingLeaf = false
    @State private var classificationService = LeafClassificationService.shared

    @State private var locationManager = CLLocationManager()
    @State private var locationDelegate: LocationDelegate?

    @State private var mapCameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 48.2082, longitude: 16.3738),
            span: MKCoordinateSpan(latitudeDelta: 0.002, longitudeDelta: 0.002)
        )
    )

    enum AddTreeStep: Int, CaseIterable {
        case gps = 0
        case mapPlacement
        case species
        case details
        case confirmation
    }

    var stepIndex: Int {
        switch step {
        case .gps, .mapPlacement: return 0
        case .species: return 1
        case .details: return 2
        case .confirmation: return 3
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                stepIndicator

                Group {
                    switch step {
                    case .gps:
                        gpsStep
                    case .mapPlacement:
                        mapPlacementStep
                    case .species:
                        speciesStep
                    case .details:
                        detailsStep
                    case .confirmation:
                        confirmationStep
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
                .animation(.easeInOut(duration: 0.3), value: step)

                if let error = errorMessage {
                    Text(error)
                        .font(.hostGrotesk(.subheadline))
                        .foregroundStyle(.red)
                        .padding()
                        .background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 24)
                        .padding(.bottom, 8)
                }
            }
            .navigationTitle("Baum melden")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        if step == .gps {
                            dismiss()
                        } else {
                            goBack()
                        }
                    } label: {
                        Image(systemName: step == .gps ? "xmark" : "chevron.left")
                    }
                }
            }
            .fullScreenCover(isPresented: $showLeafCamera) {
                LeafCameraView { image in
                    classifyLeafImage(image)
                }
            }
            .onChange(of: leafScanPhotoItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        classifyLeafImage(image)
                    }
                }
                leafScanPhotoItem = nil
            }
        }
    }

    private var stepIndicator: some View {
        HStack(spacing: 8) {
            let labels = ["Standort", "Baumart", "Details", "Fertig"]
            ForEach(Array(labels.enumerated()), id: \.offset) { index, label in
                VStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(index <= stepIndex ? Color.green : Color(.systemGray4))
                        .frame(height: 6)
                    Text(label)
                        .font(.hostGrotesk(.caption2))
                        .fontWeight(index == stepIndex ? .bold : .regular)
                        .foregroundStyle(index <= stepIndex ? .primary : .tertiary)
                }
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 12)
    }

    private var gpsStep: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "location.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)

            Text("Standort bestimmen")
                .font(.hostGrotesk(.title2))
                .fontWeight(.bold)

            Text("Halte dein Handy nahe am Baum\nund warte auf eine genaue GPS-Position.")
                .font(.hostGrotesk(.subheadline))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            gpsAccuracyView

            Button {
                locationMethod = "gps"
                withAnimation { step = .species }
            } label: {
                HStack {
                    Image(systemName: "checkmark")
                    Text("Diesen Standort verwenden")
                        .fontWeight(.bold)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .foregroundStyle(.white)
                .background(gpsAccuracy != nil && gpsAccuracy! < 25 ? .green : .gray, in: RoundedRectangle(cornerRadius: 26))
            }
            .disabled(gpsAccuracy == nil || gpsAccuracy! >= 25)
            .padding(.horizontal)

            Button {
                if let lat = latitude, let lon = longitude {
                    mapCameraPosition = .region(MKCoordinateRegion(
                        center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                        span: MKCoordinateSpan(latitudeDelta: 0.002, longitudeDelta: 0.002)
                    ))
                }
                withAnimation { step = .mapPlacement }
            } label: {
                HStack {
                    Image(systemName: "map")
                    Text("Auf Satellitenbild platzieren")
                }
                .foregroundStyle(.green)
            }

            Spacer()
        }
        .padding(.horizontal, 28)
        .onAppear { startGPS() }
        .onDisappear { stopGPS() }
    }

    private var gpsAccuracyView: some View {
        VStack(spacing: 8) {
            if let accuracy = gpsAccuracy {
                let level = gpsLevel(accuracy)
                HStack(spacing: 12) {
                    Circle()
                        .fill(level.color)
                        .frame(width: 12, height: 12)
                    Text("±\(Int(accuracy)) m")
                        .font(.hostGrotesk(.title3))
                        .fontWeight(.semibold)
                        .monospacedDigit()
                    Text("(\(level.label))")
                        .foregroundStyle(.secondary)
                }
            } else {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Warte auf GPS…")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var mapPlacementStep: some View {
        ZStack {
            Map(position: $mapCameraPosition) {
            }
            .mapStyle(.hybrid(elevation: .realistic))
            .onMapCameraChange(frequency: .onEnd) { context in
                latitude = context.camera.centerCoordinate.latitude
                longitude = context.camera.centerCoordinate.longitude
                locationMethod = "map_placement"
                gpsAccuracy = nil
            }

            Image(systemName: "mappin.circle.fill")
                .font(.system(size: 40))
                .foregroundStyle(.orange)
                .shadow(radius: 4)

            VStack {
                Spacer()
                VStack(spacing: 16) {
                    Text("Verschiebe die Karte, um den\nBaum genau zu platzieren.")
                        .font(.hostGrotesk(.subheadline))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    Button {
                        withAnimation { step = .species }
                    } label: {
                        HStack {
                            Image(systemName: "checkmark")
                            Text("Standort bestätigen")
                                .fontWeight(.bold)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .foregroundStyle(.white)
                        .background(.green, in: RoundedRectangle(cornerRadius: 26))
                    }
                }
                .padding(20)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
                .padding()
            }
        }
    }

    private var speciesStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            ZStack {
                Circle()
                    .fill(.orange.opacity(0.15))
                    .frame(width: 56, height: 56)
                Image(systemName: "tree.fill")
                    .font(.hostGrotesk(.title2))
                    .foregroundStyle(.orange)
            }

            Text("Baumart wählen")
                .font(.hostGrotesk(.title2))
                .fontWeight(.bold)

            Text("Suche nach deutschem oder wissenschaftlichem Namen")
                .font(.hostGrotesk(.subheadline))
                .foregroundStyle(.secondary)

            if selectedSpecies == nil && leafScanResults.isEmpty && !isClassifyingLeaf {
                leafScanButton
            }

            if !leafScanResults.isEmpty {
                leafScanResultsView
            }

            if isClassifyingLeaf {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Blatt wird analysiert...")
                        .font(.hostGrotesk(.subheadline))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            }

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Baumart suchen…", text: $speciesQuery)
                    .autocapitalization(.none)
                    .onChange(of: speciesQuery) { _, newValue in
                        searchSpecies(newValue)
                    }
                if isSearchingSpecies {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(.quaternary, lineWidth: 1)
            )

            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(speciesResults) { species in
                        Button {
                            selectedSpecies = species
                            speciesQuery = species.nameGerman
                            speciesResults = []
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(species.nameGerman)
                                        .font(.hostGrotesk())
                                        .fontWeight(.medium)
                                        .foregroundStyle(.primary)
                                    if let scientific = species.nameScientific {
                                        Text(scientific)
                                            .font(.hostGrotesk(.caption))
                                            .foregroundStyle(.secondary)
                                            .italic()
                                    }
                                }
                                Spacer()
                                if let cat = species.category {
                                    Text(cat)
                                        .font(.hostGrotesk(.caption2))
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(.quaternary, in: Capsule())
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if let species = selectedSpecies {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(.green.opacity(0.15))
                            .frame(width: 40, height: 40)
                        Image(systemName: "tree.fill")
                            .foregroundStyle(.green)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(species.nameGerman)
                            .fontWeight(.semibold)
                        if let scientific = species.nameScientific {
                            Text(scientific)
                                .font(.hostGrotesk(.caption))
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
                .padding()
                .background(.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
            }

            Spacer()

            if selectedSpecies != nil {
                Button {
                    withAnimation { step = .details }
                } label: {
                    Text("Weiter")
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .foregroundStyle(.white)
                        .background(.green, in: RoundedRectangle(cornerRadius: 26))
                }
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, 12)
    }

    private var detailsStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Optionale Details")
                    .font(.hostGrotesk(.title2))
                    .fontWeight(.bold)

                Text("Freiwillig, aber hilfreich für die Dokumentation.")
                    .font(.hostGrotesk(.subheadline))
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Geschätzte Höhe")
                        .fontWeight(.medium)
                    HStack {
                        TextField("z.B. 12", text: $estimatedHeight)
                            .keyboardType(.decimalPad)
                        Text("m")
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(.quaternary, lineWidth: 1)
                    )
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Stammumfang")
                        .fontWeight(.medium)
                    HStack {
                        TextField("z.B. 120", text: $estimatedTrunkCircumference)
                            .keyboardType(.numberPad)
                        Text("cm")
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(.quaternary, lineWidth: 1)
                    )
                }

                Spacer().frame(height: 20)

                HStack(spacing: 12) {
                    Button {
                        withAnimation { step = .confirmation }
                    } label: {
                        HStack {
                            Image(systemName: "forward.fill")
                                .font(.hostGrotesk(.caption))
                            Text("Überspringen")
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .foregroundStyle(.primary)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 26))
                        .overlay(
                            RoundedRectangle(cornerRadius: 26)
                                .stroke(.quaternary, lineWidth: 1)
                        )
                    }

                    Button {
                        withAnimation { step = .confirmation }
                    } label: {
                        Text("Weiter")
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .foregroundStyle(.white)
                            .background(.green, in: RoundedRectangle(cornerRadius: 26))
                    }
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, 12)
        }
    }

    private var confirmationStep: some View {
        Group {
            if submitSuccess {
                successView
            } else {
                summaryView
            }
        }
    }

    private var successView: some View {
        VStack(spacing: 24) {
            Spacer()
            ZStack {
                Circle()
                    .fill(.green.opacity(0.15))
                    .frame(width: 100, height: 100)
                Image(systemName: "checkmark")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(.green)
            }
            Text("Geschafft!")
                .font(.hostGrotesk(.largeTitle))
                .fontWeight(.bold)
            Text("Der Baum ist jetzt auf der\nCommunity-Karte sichtbar.")
                .font(.hostGrotesk(.subheadline))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                dismiss()
            }
        }
    }

    private var summaryView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Zusammenfassung")
                    .font(.hostGrotesk(.title2))
                    .fontWeight(.bold)

                Text("Prüfe die Angaben und sende den Baum ab.")
                    .font(.hostGrotesk(.subheadline))
                    .foregroundStyle(.secondary)

                VStack(spacing: 8) {
                    if let species = selectedSpecies {
                        summaryRow("Baumart", species.nameGerman)
                        if let scientific = species.nameScientific {
                            summaryRow("Wissenschaftlich", scientific)
                        }
                    }
                    if let lat = latitude, let lon = longitude {
                        summaryRow("Koordinaten", String(format: "%.5f, %.5f", lat, lon))
                    }
                    summaryRow("Standortmethode", locationMethod == "gps" ? "GPS" : "Karte")
                    if let accuracy = gpsAccuracy {
                        summaryRow("GPS-Genauigkeit", String(format: "%.1f m", accuracy))
                    }
                    if !estimatedHeight.isEmpty {
                        summaryRow("Höhe", "\(estimatedHeight) m")
                    }
                    if !estimatedTrunkCircumference.isEmpty {
                        summaryRow("Stammumfang", "\(estimatedTrunkCircumference) cm")
                    }
                }
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))

                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(.green.opacity(0.15))
                            .frame(width: 36, height: 36)
                        Image(systemName: "tree.fill")
                            .foregroundStyle(.green)
                            .font(.hostGrotesk(.subheadline))
                    }
                    Text("Wird als Community-Baum markiert und ist für alle sichtbar.")
                        .font(.hostGrotesk(.subheadline))
                }
                .padding()
                .background(.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))

                Spacer().frame(height: 20)

                Button {
                    submitTree()
                } label: {
                    Group {
                        if isSubmitting {
                            ProgressView()
                                .tint(.white)
                        } else {
                            HStack {
                                Image(systemName: "mappin.and.ellipse")
                                Text("Baum melden")
                                    .fontWeight(.bold)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .foregroundStyle(.white)
                    .background(.green, in: RoundedRectangle(cornerRadius: 28))
                }
                .disabled(isSubmitting)
            }
            .padding(.horizontal, 28)
            .padding(.top, 12)
        }
    }

    private func summaryRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }

    private var leafScanButton: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Rectangle()
                    .fill(.quaternary)
                    .frame(height: 1)
                Text("oder")
                    .font(.hostGrotesk(.caption))
                    .foregroundStyle(.tertiary)
                Rectangle()
                    .fill(.quaternary)
                    .frame(height: 1)
            }

            HStack(spacing: 12) {
                Button {
                    showLeafCamera = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "leaf.fill")
                            .foregroundStyle(.green)
                        Text("Blatt scannen")
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(.green.opacity(0.3), lineWidth: 1)
                    )
                }

                PhotosPicker(
                    selection: $leafScanPhotoItem,
                    matching: .images
                ) {
                    HStack(spacing: 8) {
                        Image(systemName: "photo.fill")
                            .foregroundStyle(.green)
                        Text("Blatt-Foto")
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(.green.opacity(0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var leafScanResultsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "leaf.fill")
                    .foregroundStyle(.green)
                Text("Scan-Ergebnisse")
                    .font(.hostGrotesk(.subheadline))
                    .fontWeight(.semibold)
                Spacer()
                Button {
                    leafScanResults = []
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }

            ForEach(Array(leafScanResults.prefix(3).enumerated()), id: \.element.id) { index, result in
                Button {
                    selectSpeciesFromScan(result)
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(index == 0 ? .green.opacity(0.15) : .gray.opacity(0.1))
                                .frame(width: 32, height: 32)
                            Text("\(index + 1)")
                                .font(.hostGrotesk(.caption))
                                .fontWeight(.bold)
                                .foregroundStyle(index == 0 ? .green : .secondary)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(result.speciesGerman)
                                .font(.hostGrotesk())
                                .fontWeight(.medium)
                                .foregroundStyle(.primary)
                            if !result.speciesLatin.isEmpty {
                                Text(result.speciesLatin)
                                    .font(.hostGrotesk(.caption))
                                    .foregroundStyle(.secondary)
                                    .italic()
                            }
                        }
                        Spacer()
                        Text("\(result.confidencePercent)%")
                            .font(.hostGrotesk(.subheadline))
                            .fontWeight(.semibold)
                            .foregroundStyle(index == 0 ? .green : .secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        index == 0 ? .green.opacity(0.06) : .clear,
                        in: RoundedRectangle(cornerRadius: 12)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.green.opacity(0.2), lineWidth: 1)
        )
    }

    private func classifyLeafImage(_ image: UIImage) {
        isClassifyingLeaf = true
        leafScanResults = []

        classificationService.classify(image: image)

        Task {

            while classificationService.isClassifying {
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
            await MainActor.run {
                isClassifyingLeaf = false
                leafScanResults = classificationService.lastResults

                classificationService.reset()
            }
        }
    }

    private func selectSpeciesFromScan(_ result: LeafClassificationResult) {

        Task {
            let results = await CommunityTreeService.shared.searchSpecies(query: result.speciesGerman)
            await MainActor.run {
                if let match = results.first {
                    selectedSpecies = match
                    speciesQuery = match.nameGerman
                } else {

                    speciesQuery = result.speciesGerman
                    searchSpecies(result.speciesGerman)
                }
                leafScanResults = []
                speciesResults = []
            }
        }
    }

    private func startGPS() {
        let delegate = LocationDelegate { location in
            latitude = location.coordinate.latitude
            longitude = location.coordinate.longitude
            gpsAccuracy = location.horizontalAccuracy
        }
        self.locationDelegate = delegate
        locationManager.delegate = delegate
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }

    private func stopGPS() {
        locationManager.stopUpdatingLocation()
        locationDelegate = nil
    }

    private func gpsLevel(_ accuracy: Double) -> (label: String, color: Color) {
        switch accuracy {
        case ..<5: return ("Ausgezeichnet", .green)
        case ..<10: return ("Gut", .green)
        case ..<25: return ("Mittel", .orange)
        default: return ("Schlecht", .red)
        }
    }

    private func searchSpecies(_ query: String) {
        searchTask?.cancel()
        guard query.count >= 2 else {
            speciesResults = []
            return
        }

        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            if Task.isCancelled { return }
            isSearchingSpecies = true
            let results = await CommunityTreeService.shared.searchSpecies(query: query)
            if !Task.isCancelled {
                speciesResults = results
                isSearchingSpecies = false
            }
        }
    }

    private func goBack() {
        withAnimation {
            switch step {
            case .gps: break
            case .mapPlacement: step = .gps
            case .species: step = .gps
            case .details: step = .species
            case .confirmation: step = .details
            }
        }
    }

    private func submitTree() {
        guard let userId = authService.getCurrentUserId() else {
            errorMessage = "Nicht angemeldet"
            return
        }
        guard let species = selectedSpecies else {
            errorMessage = "Bitte Baumart wählen"
            return
        }
        guard let lat = latitude, let lon = longitude else {
            errorMessage = "Kein Standort"
            return
        }

        isSubmitting = true
        errorMessage = nil

        let insert = CommunityTreeInsert(
            userId: userId,
            userDisplayName: authService.getCurrentDisplayName(),
            speciesGerman: species.nameGerman,
            speciesScientific: species.nameScientific,
            latitude: lat,
            longitude: lon,
            district: nil,
            street: nil,
            estimatedHeight: Double(estimatedHeight),
            estimatedTrunkCircumference: Int(estimatedTrunkCircumference),
            gpsAccuracyMeters: gpsAccuracy,
            locationMethod: locationMethod
        )

        Task {
            do {
                let _ = try await CommunityTreeService.shared.addCommunityTree(insert)
                await MainActor.run {
                    isSubmitting = false
                    withAnimation { submitSuccess = true }
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

private class LocationDelegate: NSObject, CLLocationManagerDelegate {
    let onLocation: (CLLocation) -> Void

    init(onLocation: @escaping (CLLocation) -> Void) {
        self.onLocation = onLocation
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            onLocation(location)
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }
}

#Preview {
    AddTreeView()
}
