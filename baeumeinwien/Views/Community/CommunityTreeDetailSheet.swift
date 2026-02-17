import SwiftUI
import MapKit
import CoreLocation

struct CommunityTreeDetailSheet: View {
    let tree: CommunityTree
    @State private var authService = AuthService.shared
    @State private var wikiSummary: WikipediaSummary?
    @State private var isLoadingWiki = false
    @State private var showReportSheet = false
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var deleteError: String?
    @State private var reportSuccess = false
    @State private var deleteSuccess = false
    @Environment(\.dismiss) private var dismiss

    private var isOwner: Bool {
        guard let userId = authService.authState.userId else { return false }
        return tree.userId == userId
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {

                headerSection

                if let summary = wikiSummary {
                    wikiSection(summary)
                } else if isLoadingWiki {
                    ProgressView()
                        .padding()
                }

                statsGrid

                creatorSection

                locationSection

                miniMapSection

                actionButtons

                if !tree.isOfficialTree {
                    moderationSection
                }

                if reportSuccess {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Baum wurde gemeldet. Danke!")
                            .font(.hostGrotesk(.subheadline))
                    }
                    .padding()
                    .background(.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                }

                if deleteSuccess {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Baum wurde gelöscht.")
                            .font(.hostGrotesk(.subheadline))
                    }
                    .padding()
                    .background(.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                }

                if let error = deleteError {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                        Text(error)
                            .font(.hostGrotesk(.subheadline))
                    }
                    .padding()
                    .background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding()
            .padding(.bottom, 20)
        }
        .onAppear {
            loadWikipediaInfo()
        }
        .sheet(isPresented: $showReportSheet) {
            ReportTreeSheet(tree: tree, onSuccess: {
                reportSuccess = true
            })
        }
        .alert("Baum löschen?", isPresented: $showDeleteConfirmation) {
            Button("Abbrechen", role: .cancel) { }
            Button("Löschen", role: .destructive) {
                deleteTree()
            }
        } message: {
            Text("Möchtest du diesen Baum wirklich löschen? Diese Aktion kann nicht rückgängig gemacht werden.")
        }
    }

    private var moderationSection: some View {
        VStack(spacing: 12) {

            if isOwner {
                Button {
                    showDeleteConfirmation = true
                } label: {
                    HStack(spacing: 8) {
                        if isDeleting {
                            ProgressView()
                                .tint(.red)
                        } else {
                            Image(systemName: "trash")
                        }
                        Text("Baum löschen")
                    }
                    .font(.hostGrotesk(.subheadline, weight: .medium))
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.red.opacity(0.2), lineWidth: 1)
                    )
                }
                .disabled(isDeleting || deleteSuccess)
            }

            if authService.authState.isAuthenticated && !isOwner {
                Button {
                    showReportSheet = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "flag")
                        Text("Baum melden")
                    }
                    .font(.hostGrotesk(.subheadline, weight: .medium))
                    .foregroundStyle(.orange)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.orange.opacity(0.2), lineWidth: 1)
                    )
                }
                .disabled(reportSuccess)
            }
        }
    }

    private func deleteTree() {
        guard let userId = authService.authState.userId else { return }
        isDeleting = true
        deleteError = nil

        Task {
            do {
                try await CommunityTreeService.shared.deleteCommunityTree(treeId: tree.id, userId: userId)
                await MainActor.run {
                    isDeleting = false
                    deleteSuccess = true

                    AppState.shared.communityTrees.removeAll { $0.id == tree.id }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        dismiss()
                    }
                }
            } catch {
                await MainActor.run {
                    isDeleting = false
                    deleteError = error.localizedDescription
                }
            }
        }
    }

    private func loadWikipediaInfo() {
        isLoadingWiki = true
        Task {
            if let summary = try? await WikipediaService.shared.fetchSummary(for: tree.speciesGerman) {
                await MainActor.run {
                    self.wikiSummary = summary
                    self.isLoadingWiki = false
                }
            } else if let scientific = tree.speciesScientific,
                      let summary = try? await WikipediaService.shared.fetchSummary(for: scientific) {
                await MainActor.run {
                    self.wikiSummary = summary
                    self.isLoadingWiki = false
                }
            } else {
                await MainActor.run {
                    self.isLoadingWiki = false
                }
            }
        }
    }

    private func wikiSection(_ summary: WikipediaSummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let imageUrl = summary.thumbnail?.source, let url = URL(string: imageUrl) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.1))
                        .frame(height: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(ProgressView())
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Über diese Baumart")
                    .font(.hostGrotesk(.headline, weight: .semibold))
                    .foregroundStyle(.secondary)

                Text(summary.extract)
                    .font(.hostGrotesk())
                    .fixedSize(horizontal: false, vertical: true)

                if let pageUrl = summary.content_urls?.mobile?.page, let url = URL(string: pageUrl) {
                    Link(destination: url) {
                        HStack(spacing: 4) {
                            Text("Mehr auf Wikipedia")
                            Image(systemName: "arrow.up.right")
                        }
                        .font(.hostGrotesk(.caption))
                        .foregroundStyle(.blue)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private var headerSection: some View {
        VStack(spacing: 12) {

            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.2))
                    .frame(width: 80, height: 80)

                Circle()
                    .fill(statusColor)
                    .frame(width: 60, height: 60)

                Image(systemName: statusIcon)
                    .font(.system(size: 28))
                    .foregroundStyle(.white)
            }

            VStack(spacing: 4) {
                Text(tree.speciesGerman)
                    .font(.hostGrotesk(.title2))
                    .fontWeight(.bold)

                if let scientific = tree.speciesScientific {
                    Text(scientific)
                        .font(.hostGrotesk(.subheadline))
                        .foregroundStyle(.secondary)
                        .italic()
                }
            }

            verificationBadge
        }
    }

    private var verificationBadge: some View {
        Group {
            if tree.isOfficialTree {

                HStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.blue)
                    Text("Offiziell erfasst")
                        .font(.hostGrotesk(.subheadline))
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.12), in: Capsule())
            } else if tree.status == "verified" {

                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Vom Team bestätigt")
                        .font(.hostGrotesk(.subheadline))
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.green.opacity(0.12), in: Capsule())
            } else {

                HStack(spacing: 6) {
                    Image(systemName: "person.fill")
                        .foregroundStyle(.orange)
                    Text("Community-Meldung")
                        .font(.hostGrotesk(.subheadline))
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.12), in: Capsule())
            }
        }
    }

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            if let height = tree.estimatedHeight {
                StatCard(icon: "arrow.up.and.down", title: "Höhe (ca.)", value: "\(String(format: "%.1f", height)) m", color: .blue)
            }

            if let trunk = tree.estimatedTrunkCircumference {
                StatCard(icon: "circle", title: "Stammumfang (ca.)", value: "\(trunk) cm", color: .brown)
            }

            if let district = tree.district {
                StatCard(icon: "mappin.circle", title: "Bezirk", value: "\(district). Bezirk", color: .purple)
            }

            if tree.confirmationCount > 0 {
                StatCard(icon: "hand.thumbsup.fill", title: "Bestätigungen", value: "\(tree.confirmationCount)", color: .green)
            }
        }
    }

    private var creatorSection: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(creatorColor.opacity(0.15))
                    .frame(width: 40, height: 40)

                Image(systemName: creatorIcon)
                    .foregroundStyle(creatorColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Gemeldet von")
                    .font(.hostGrotesk(.caption))
                    .foregroundStyle(.secondary)
                Text(tree.creatorDisplayText)
                    .font(.hostGrotesk(.subheadline))
                    .fontWeight(.medium)
                if let dateText = formattedDate {
                    Text(dateText)
                        .font(.hostGrotesk(.caption2))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if let statusText = tree.officialStatusText {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(.blue)
                    .help(statusText)
            }
        }
        .padding(14)
        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 16))
    }

    private var locationSection: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.15))
                    .frame(width: 40, height: 40)

                Image(systemName: "location.fill")
                    .foregroundStyle(.blue)
            }

            VStack(alignment: .leading, spacing: 4) {
                if let street = tree.street {
                    Text(street)
                        .font(.hostGrotesk(.subheadline))
                        .fontWeight(.medium)
                }
                Text("\(String(format: "%.5f", tree.latitude)), \(String(format: "%.5f", tree.longitude))")
                    .font(.hostGrotesk(.caption))
                    .foregroundStyle(.secondary)
                    .fontDesign(.monospaced)

                if let accuracy = tree.gpsAccuracyMeters {
                    Text("GPS-Genauigkeit: ±\(String(format: "%.0f", accuracy)) m")
                        .font(.hostGrotesk(.caption2))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button {
                openInMaps()
            } label: {
                Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                    .font(.hostGrotesk(.title3))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 40, height: 40)
                    .background(Color(.systemGray6), in: Circle())
            }
        }
        .padding(14)
        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 16))
    }

    private var miniMapSection: some View {
        Map(initialPosition: .region(
            MKCoordinateRegion(
                center: tree.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.002, longitudeDelta: 0.002)
            )
        )) {
            Marker(tree.speciesGerman, coordinate: tree.coordinate)
                .tint(statusColor)
        }
        .frame(height: 150)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .allowsHitTesting(false)
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button {
                openInMaps()
            } label: {
                Label("Route", systemImage: "arrow.triangle.turn.up.right.diamond")
                    .font(.hostGrotesk(.subheadline, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))
            }

            ShareLink(
                item: "🌳 \(tree.speciesGerman)\n📍 \(tree.street ?? "Wien")\nhttps://maps.apple.com/?ll=\(tree.latitude),\(tree.longitude)",
                subject: Text("Community-Baum: \(tree.speciesGerman)"),
                message: Text("Schau dir diesen Community-Baum an!")
            ) {
                Label("Teilen", systemImage: "square.and.arrow.up")
                    .font(.hostGrotesk(.subheadline, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var statusColor: Color {
        if tree.isOfficialTree { return .blue }
        return .orange
    }

    private var statusIcon: String {
        if tree.isOfficialTree { return "checkmark.seal.fill" }
        return "leaf.fill"
    }

    private var creatorColor: Color {
        if tree.isOfficialTree { return .blue }
        return .green
    }

    private var creatorIcon: String {
        if tree.isOfficialTree { return "building.2.fill" }
        return "person.fill"
    }

    private var formattedDate: String? {
        guard let dateString = tree.createdAt else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.locale = Locale(identifier: "de_AT")
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }

        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.locale = Locale(identifier: "de_AT")
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }
        return nil
    }

    private func openInMaps() {
        let location = CLLocation(latitude: tree.coordinate.latitude, longitude: tree.coordinate.longitude)
        let mapItem = MKMapItem(location: location, address: nil)
        mapItem.name = tree.speciesGerman
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking
        ])
    }
}

struct ReportTreeSheet: View {
    let tree: CommunityTree
    var onSuccess: () -> Void

    @State private var selectedReason = "incorrect_location"
    @State private var comment = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var authService = AuthService.shared
    @Environment(\.dismiss) private var dismiss

    private let reportReasons = [
        ("incorrect_location", "Falscher Standort", "location.slash"),
        ("incorrect_species", "Falsche Baumart", "leaf.arrow.triangle.circlepath"),
        ("tree_removed", "Baum existiert nicht mehr", "xmark.circle"),
        ("duplicate", "Duplikat", "doc.on.doc"),
        ("spam", "Spam / Unsinn", "exclamationmark.triangle"),
        ("other", "Sonstiges", "ellipsis.circle")
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {

                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.orange.opacity(0.15))
                                .frame(width: 44, height: 44)
                            Image(systemName: "leaf.fill")
                                .foregroundStyle(.orange)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(tree.speciesGerman)
                                .font(.hostGrotesk(.headline, weight: .semibold))
                            if let street = tree.street {
                                Text(street)
                                    .font(.hostGrotesk(.caption))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                    }
                    .padding()
                    .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Grund der Meldung")
                            .font(.hostGrotesk(.headline, weight: .semibold))

                        ForEach(reportReasons, id: \.0) { reason in
                            Button {
                                selectedReason = reason.0
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: reason.2)
                                        .foregroundStyle(selectedReason == reason.0 ? .orange : .secondary)
                                        .frame(width: 24)

                                    Text(reason.1)
                                        .foregroundStyle(.primary)

                                    Spacer()

                                    if selectedReason == reason.0 {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.orange)
                                    } else {
                                        Image(systemName: "circle")
                                            .foregroundStyle(.quaternary)
                                    }
                                }
                                .padding(12)
                                .background(
                                    selectedReason == reason.0 ? Color.orange.opacity(0.08) : Color(.systemGray6),
                                    in: RoundedRectangle(cornerRadius: 10)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(selectedReason == reason.0 ? Color.orange.opacity(0.3) : .clear, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Kommentar (optional)")
                            .font(.hostGrotesk(.headline, weight: .semibold))

                        TextField("Weitere Details...", text: $comment, axis: .vertical)
                            .lineLimit(3...6)
                            .padding(12)
                            .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))
                    }

                    if let error = errorMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                            Text(error)
                                .font(.hostGrotesk(.subheadline))
                        }
                        .padding()
                        .background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                    }

                    Button {
                        submitReport()
                    } label: {
                        Group {
                            if isSubmitting {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Label("Meldung absenden", systemImage: "flag.fill")
                            }
                        }
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .foregroundStyle(.white)
                        .background(.orange, in: RoundedRectangle(cornerRadius: 24))
                    }
                    .disabled(isSubmitting)
                }
                .padding()
            }
            .navigationTitle("Baum melden")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
            }
        }
    }

    private func submitReport() {
        guard let userId = authService.authState.userId else {
            errorMessage = "Du musst angemeldet sein, um einen Baum zu melden."
            return
        }

        isSubmitting = true
        errorMessage = nil

        Task {
            do {
                try await CommunityTreeService.shared.reportTree(
                    treeId: tree.id,
                    reporterId: userId,
                    reason: selectedReason,
                    comment: comment.isEmpty ? nil : comment
                )
                await MainActor.run {
                    isSubmitting = false
                    onSuccess()
                    dismiss()
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
