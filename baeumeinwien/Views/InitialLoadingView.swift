import SwiftUI

struct InitialLoadingView: View {
    @State private var appState = AppState.shared
    @State private var showTip = false

    var body: some View {
        ZStack {

            LinearGradient(
                colors: [
                    Color.green.opacity(0.3),
                    Color.mint.opacity(0.2),
                    Color(.systemBackground)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                Image(systemName: "tree.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.green, .mint],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .symbolEffect(.pulse, options: .repeating)

                VStack(spacing: 12) {
                    Text("Bäume in Wien")
                        .font(.hostGrotesk(.largeTitle))
                        .fontWeight(.bold)

                    Text("wird vorbereitet...")
                        .font(.hostGrotesk(.title3))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(spacing: 16) {

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.2))

                            RoundedRectangle(cornerRadius: 8)
                                .fill(
                                    LinearGradient(
                                        colors: [.green, .mint],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * appState.loadingProgress)
                                .animation(.easeInOut(duration: 0.3), value: appState.loadingProgress)
                        }
                    }
                    .frame(height: 12)
                    .padding(.horizontal, 40)

                    Text(appState.loadingMessage)
                        .font(.hostGrotesk(.subheadline))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    Text("\(Int(appState.loadingProgress * 100))%")
                        .font(.hostGrotesk(.title2))
                        .fontWeight(.semibold)
                        .foregroundStyle(.green)
                        .contentTransition(.numericText())
                        .animation(.easeInOut, value: appState.loadingProgress)
                }

                Spacer()

                if showTip {
                    VStack(spacing: 8) {
                        Text("💡 Tipp")
                            .font(.hostGrotesk(.caption))
                            .fontWeight(.semibold)
                        Text("Die App funktioniert auch offline, nachdem die Baumdaten einmal geladen wurden.")
                            .font(.hostGrotesk(.caption))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 32)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                Spacer()
                    .frame(height: 60)
            }
        }
        .onAppear {

            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation(.spring(duration: 0.5)) {
                    showTip = true
                }
            }
        }
    }
}

#Preview {
    InitialLoadingView()
}
