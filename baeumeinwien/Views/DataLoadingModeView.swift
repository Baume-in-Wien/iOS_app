import SwiftUI

struct DataLoadingModeView: View {
    @Binding var selectedMode: LoadingMode?

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "tree.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.green.gradient)

                Text("Baumdaten laden")
                    .font(.largeTitle.bold())

                Text("Wie möchtest du die Baumdaten laden?")
                    .font(.hostGrotesk(.subheadline))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            VStack(spacing: 16) {

                Button {
                    selectedMode = .onDemand
                } label: {
                    HStack(spacing: 16) {
                        Image(systemName: "icloud.and.arrow.down")
                            .font(.hostGrotesk(.title))
                            .frame(width: 44)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Bei Bedarf laden")
                                .font(.hostGrotesk(.headline, weight: .semibold))
                            Text("Daten werden im Hintergrund geladen während du die App nutzt")
                                .font(.hostGrotesk(.caption))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)

                Button {
                    selectedMode = .bulk
                } label: {
                    HStack(spacing: 16) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.hostGrotesk(.title))
                            .frame(width: 44)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Alle Daten jetzt laden")
                                .font(.hostGrotesk(.headline, weight: .semibold))
                            Text("~140 MB herunterladen – danach funktioniert alles offline")
                                .font(.hostGrotesk(.caption))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)

            Spacer()
        }
        .padding()
    }
}

#Preview {
    DataLoadingModeView(selectedMode: .constant(nil))
}
