import SwiftUI

struct RallyJoinView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var code = ""
    @State private var displayName = ""
    @State private var isJoining = false
    @State private var errorMessage: String?
    @FocusState private var isCodeFocused: Bool

    let onJoin: (Rally) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                Image(systemName: "person.3.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.green, .mint],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                VStack(spacing: 12) {
                    Text("Rally beitreten")
                        .font(.largeTitle.bold())

                    Text("Gib den 6-stelligen Code ein")
                        .font(.hostGrotesk(.subheadline))
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 16) {
                    TextField("CODE", text: $code)
                        .font(.system(size: 36, weight: .bold, design: .monospaced))
                        .multilineTextAlignment(.center)
                        .textCase(.uppercase)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.characters)
                        .padding()
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(code.count == 6 ? Color.green : Color.secondary.opacity(0.3), lineWidth: 2)
                        )
                        .focused($isCodeFocused)
                        .onChange(of: code) { _, newValue in
                            code = String(newValue.uppercased().prefix(6))
                        }

                    TextField("Dein Name (z.B. Team 1)", text: $displayName)
                        .textContentType(.name)
                        .padding()
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)

                if let error = errorMessage {
                    Text(error)
                        .font(.hostGrotesk(.subheadline))
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                }

                Spacer()

                Button {
                    joinRally()
                } label: {
                    if isJoining {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Beitreten")
                            .font(.hostGrotesk(.headline, weight: .semibold))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .foregroundStyle(.white)
                .background(canJoin ? Color.green : Color.gray)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .disabled(!canJoin || isJoining)
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                isCodeFocused = true
            }
        }
    }

    private var canJoin: Bool {
        code.count == 6 && !displayName.isEmpty
    }

    private func joinRally() {
        Task {
            isJoining = true
            errorMessage = nil

            let result = await SupabaseService.shared.joinRally(code: code, displayName: displayName)

            await MainActor.run {
                isJoining = false

                switch result {
                case .success(let rally):
                    onJoin(rally)
                    dismiss()
                case .error(let message):
                    errorMessage = message
                }
            }
        }
    }
}

#Preview {
    RallyJoinView { _ in }
}
