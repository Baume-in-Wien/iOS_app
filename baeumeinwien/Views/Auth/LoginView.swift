import SwiftUI

struct LoginView: View {
    @State private var authService = AuthService.shared
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUpMode = false
    @State private var passwordVisible = false
    @State private var signUpSuccess = false
    @Environment(\.dismiss) private var dismiss

    @State private var floatOffset: CGFloat = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    Spacer().frame(height: 20)

                    heroIllustration

                    Spacer().frame(height: 20)

                    Text("Willkommen!")
                        .font(.hostGrotesk(.largeTitle))
                        .fontWeight(.bold)

                    Spacer().frame(height: 4)

                    Text("Melde dich an, um Bäume zur\nCommunity-Karte hinzuzufügen")
                        .font(.hostGrotesk(.subheadline))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    Spacer().frame(height: 28)

                    if signUpSuccess {
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("Registrierung erfolgreich! Du kannst dich jetzt anmelden.")
                                .font(.hostGrotesk(.subheadline))
                        }
                        .padding()
                        .background(.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                        .padding(.bottom, 16)
                    }

                    Button {
                        Task { await authService.signInWithApple() }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "apple.logo")
                                .font(.system(size: 20, weight: .semibold))
                            Text("Mit Apple anmelden")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .foregroundStyle(.white)
                        .background(.black, in: RoundedRectangle(cornerRadius: 26))
                    }
                    .buttonStyle(.plain)

                    Spacer().frame(height: 12)

                    Button {
                        Task { await authService.signInWithGitHub() }
                    } label: {
                        HStack(spacing: 10) {
                            GitHubLogoView()
                                .frame(width: 22, height: 22)
                            Text("Mit GitHub anmelden")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .foregroundStyle(.white)
                        .background(Color(.darkGray), in: RoundedRectangle(cornerRadius: 26))
                    }
                    .buttonStyle(.plain)

                    Spacer().frame(height: 24)

                    HStack {
                        Rectangle().fill(.quaternary).frame(height: 1)
                        Text("oder mit E-Mail")
                            .font(.hostGrotesk(.caption))
                            .foregroundStyle(.tertiary)
                        Rectangle().fill(.quaternary).frame(height: 1)
                    }

                    Spacer().frame(height: 20)

                    HStack(spacing: 10) {
                        Image(systemName: "envelope")
                            .foregroundStyle(.secondary)
                            .frame(width: 20)
                        TextField("E-Mail", text: $email)
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .autocapitalization(.none)
                    }
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(.quaternary, lineWidth: 1)
                    )

                    Spacer().frame(height: 12)

                    HStack(spacing: 10) {
                        Image(systemName: "lock")
                            .foregroundStyle(.secondary)
                            .frame(width: 20)
                        if passwordVisible {
                            TextField("Passwort", text: $password)
                                .textContentType(.password)
                        } else {
                            SecureField("Passwort", text: $password)
                                .textContentType(.password)
                        }
                        Button {
                            passwordVisible.toggle()
                        } label: {
                            Image(systemName: passwordVisible ? "eye" : "eye.slash")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(.quaternary, lineWidth: 1)
                    )

                    Spacer().frame(height: 20)

                    Button {
                        Task {
                            if isSignUpMode {
                                let success = await authService.signUpWithEmail(email: email, password: password)
                                if success {
                                    signUpSuccess = true
                                    isSignUpMode = false
                                }
                            } else {
                                await authService.signInWithEmail(email: email, password: password)
                            }
                        }
                    } label: {
                        Group {
                            if case .loading = authService.authState {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text(isSignUpMode ? "Registrieren" : "Anmelden")
                                    .fontWeight(.bold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .foregroundStyle(.white)
                        .background(.green, in: RoundedRectangle(cornerRadius: 26))
                    }
                    .disabled(authService.authState == .loading)

                    Spacer().frame(height: 8)

                    Button {
                        withAnimation { isSignUpMode.toggle() }
                    } label: {
                        Text(isSignUpMode ? "Bereits ein Konto? Anmelden" : "Noch kein Konto? Registrieren")
                            .font(.hostGrotesk(.subheadline))
                            .foregroundStyle(.green)
                    }

                    if case .error(let message) = authService.authState {
                        Text(message)
                            .font(.hostGrotesk(.subheadline))
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding()
                            .background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                            .padding(.top, 12)
                    }

                    Spacer().frame(height: 32)
                }
                .padding(.horizontal, 24)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
            }
            .onChange(of: authService.authState) { _, newState in
                if newState.isAuthenticated {
                    dismiss()
                }
            }
        }
    }

    private var heroIllustration: some View {
        ZStack {

            Image(systemName: "tree.fill")
                .font(.hostGrotesk(.title))
                .foregroundStyle(.green.opacity(0.15))
                .offset(x: -44, y: floatOffset * 0.6)

            Image(systemName: "tree.fill")
                .font(.hostGrotesk(.title3))
                .foregroundStyle(.orange.opacity(0.15))
                .offset(x: 48, y: -floatOffset * 0.4)

            ZStack {
                Circle()
                    .fill(.green.opacity(0.15))
                    .frame(width: 88, height: 88)

                Image(systemName: "leaf.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.green)
            }
            .offset(y: floatOffset)
        }
        .frame(height: 120)
        .onAppear {
            withAnimation(.easeInOut(duration: 3.5).repeatForever(autoreverses: true)) {
                floatOffset = 6
            }
        }
    }
}

#Preview {
    LoginView()
}
