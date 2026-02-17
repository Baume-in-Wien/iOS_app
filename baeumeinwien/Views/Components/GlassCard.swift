import SwiftUI

struct LiquidGlass {

    static let softShadow = ShadowStyle.drop(color: .black.opacity(0.15), radius: 30, y: 15)

    static let mediumShadow = ShadowStyle.drop(color: .black.opacity(0.12), radius: 20, y: 10)

    static let lightShadow = ShadowStyle.drop(color: .black.opacity(0.08), radius: 12, y: 6)

    static let highlightGradient = LinearGradient(
        colors: [.white.opacity(0.5), .white.opacity(0.1)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let innerHighlight = LinearGradient(
        colors: [.white.opacity(0.3), .clear],
        startPoint: .top,
        endPoint: .center
    )
}

struct GlassCard<Content: View>: View {
    let content: Content
    var padding: CGFloat = 16
    var cornerRadius: CGFloat = 20
    var elevation: GlassElevation = .medium

    enum GlassElevation {
        case low, medium, high

        var shadowRadius: CGFloat {
            switch self {
            case .low: return 10
            case .medium: return 20
            case .high: return 30
            }
        }

        var shadowOpacity: Double {
            switch self {
            case .low: return 0.08
            case .medium: return 0.12
            case .high: return 0.15
            }
        }

        var shadowY: CGFloat {
            switch self {
            case .low: return 5
            case .medium: return 10
            case .high: return 15
            }
        }
    }

    init(padding: CGFloat = 16, cornerRadius: CGFloat = 20, elevation: GlassElevation = .medium, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.elevation = elevation
    }

    var body: some View {
        content
            .padding(padding)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        LiquidGlass.highlightGradient,
                        lineWidth: 0.5
                    )
            )
            .shadow(color: .black.opacity(elevation.shadowOpacity), radius: elevation.shadowRadius, x: 0, y: elevation.shadowY)
    }
}

struct GlassButton: View {
    let title: String
    let icon: String?
    let action: () -> Void
    var buttonStyle: GlassButtonStyle = .primary

    init(title: String, icon: String?, action: @escaping () -> Void, style: GlassButtonStyle = .primary) {
        self.title = title
        self.icon = icon
        self.action = action
        self.buttonStyle = style
    }

    enum GlassButtonStyle {
        case primary, secondary, destructive

        var foregroundColor: Color {
            switch self {
            case .primary: return .white
            case .secondary: return .primary
            case .destructive: return .red
            }
        }

        var backgroundStyle: AnyShapeStyle {
            switch self {
            case .primary:
                return AnyShapeStyle(LinearGradient(
                    colors: [Color.accentColor, Color.accentColor.opacity(0.85)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
            case .secondary:
                return AnyShapeStyle(.ultraThinMaterial)
            case .destructive:
                return AnyShapeStyle(Color.red.opacity(0.15))
            }
        }

        var shadowColor: Color {
            switch self {
            case .primary: return .accentColor.opacity(0.4)
            case .secondary: return .black.opacity(0.1)
            case .destructive: return .red.opacity(0.3)
            }
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                        .font(.hostGrotesk(.body, weight: .semibold))
                }
                Text(title)
                    .fontWeight(.semibold)
            }
            .foregroundStyle(buttonStyle.foregroundColor)
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(buttonStyle.backgroundStyle, in: Capsule())
            .overlay(
                Capsule()
                    .stroke(
                        buttonStyle == .primary
                            ? LinearGradient(colors: [.white.opacity(0.3), .white.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing)
                            : LiquidGlass.highlightGradient,
                        lineWidth: 0.5
                    )
            )
            .shadow(color: buttonStyle.shadowColor, radius: 12, x: 0, y: 6)
        }
        .buttonStyle(GlassPressStyle())
    }

    func style(_ style: GlassButtonStyle) -> GlassButton {
        var copy = self
        copy.buttonStyle = style
        return copy
    }
}

struct GlassPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(duration: 0.2), value: configuration.isPressed)
    }
}

struct GlassFloatingButton: View {
    let icon: String
    let action: () -> Void
    var size: CGFloat = 56

    var body: some View {
        Button(action: action) {
            ZStack {

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(0.2), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Image(systemName: icon)
                    .font(.hostGrotesk(.title2))
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
            }
            .frame(width: size, height: size)
            .background(
                LinearGradient(
                    colors: [Color.accentColor, Color.accentColor.opacity(0.85)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: Circle()
            )
            .overlay(
                Circle()
                    .stroke(.white.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: .accentColor.opacity(0.4), radius: 15, x: 0, y: 8)
        }
        .buttonStyle(GlassPressStyle())
    }
}

struct GlassChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.hostGrotesk(.subheadline))
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundStyle(isSelected ? .white : .primary)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(
                    isSelected ?
                    AnyShapeStyle(LinearGradient(
                        colors: [Color.accentColor, Color.accentColor.opacity(0.85)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )) : AnyShapeStyle(.ultraThinMaterial),
                    in: Capsule()
                )
                .overlay(
                    Capsule()
                        .stroke(
                            isSelected
                                ? LinearGradient(colors: [.white.opacity(0.3), .white.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                : LiquidGlass.highlightGradient,
                            lineWidth: 0.5
                        )
                )
                .shadow(
                    color: isSelected ? .accentColor.opacity(0.3) : .black.opacity(0.05),
                    radius: isSelected ? 8 : 4,
                    y: isSelected ? 4 : 2
                )
        }
        .buttonStyle(GlassPressStyle())
        .animation(.spring(duration: 0.3), value: isSelected)
    }
}

struct GlassProgressBar: View {
    let progress: Double
    let label: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let label {
                Text(label)
                    .font(.hostGrotesk(.caption))
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {

                    Capsule()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Capsule()
                                .stroke(LiquidGlass.highlightGradient, lineWidth: 0.5)
                        )
                        .frame(height: 8)

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.accentColor, .accentColor.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(geometry.size.width * CGFloat(progress), 8), height: 8)
                        .overlay(

                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [.white.opacity(0.4), .clear],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(height: 4)
                                .offset(y: -1)
                        )
                        .shadow(color: .accentColor.opacity(0.3), radius: 4, y: 2)
                        .animation(.spring(duration: 0.5), value: progress)
                }
            }
            .frame(height: 8)
        }
    }
}

struct GlassSectionHeader: View {
    let title: String
    let icon: String?

    init(_ title: String, icon: String? = nil) {
        self.title = title
        self.icon = icon
    }

    var body: some View {
        HStack(spacing: 8) {
            if let icon {
                Image(systemName: icon)
                    .font(.hostGrotesk(.subheadline))
                    .foregroundStyle(.secondary)
            }
            Text(title)
                .font(.hostGrotesk(.subheadline))
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .textCase(nil)
    }
}

struct ConfettiView: View {
    @State private var isAnimating = false
    let colors: [Color] = [.yellow, .orange, .green, .blue, .purple, .pink]

    var body: some View {
        ZStack {
            ForEach(0..<50, id: \.self) { i in
                Circle()
                    .fill(colors[i % colors.count])
                    .frame(width: CGFloat.random(in: 4...10))
                    .offset(
                        x: isAnimating ? CGFloat.random(in: -200...200) : 0,
                        y: isAnimating ? CGFloat.random(in: 200...600) : -50
                    )
                    .opacity(isAnimating ? 0 : 1)
                    .animation(
                        .easeOut(duration: Double.random(in: 1...2))
                        .delay(Double.random(in: 0...0.5)),
                        value: isAnimating
                    )
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}

#Preview("Glass Card") {
    ZStack {
        LinearGradient(colors: [.blue.opacity(0.3), .purple.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing)
            .ignoresSafeArea()

        VStack(spacing: 20) {
            GlassCard(elevation: .low) {
                Text("Low Elevation")
            }

            GlassCard(elevation: .medium) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Winterlinde")
                        .font(.hostGrotesk(.title2))
                        .fontWeight(.bold)
                    Text("Tilia cordata")
                        .font(.hostGrotesk(.subheadline))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            GlassCard(elevation: .high) {
                Text("High Elevation")
            }
        }
        .padding()
    }
}

#Preview("Glass Buttons") {
    ZStack {
        Color.gray.opacity(0.2).ignoresSafeArea()

        VStack(spacing: 20) {
            GlassButton(title: "Starten", icon: "play.fill", action: {}, style: .primary)
            GlassButton(title: "Abbrechen", icon: nil, action: {}, style: .secondary)
            GlassButton(title: "Löschen", icon: "trash", action: {}, style: .destructive)

            HStack(spacing: 12) {
                GlassChip(title: "500m", isSelected: false, action: {})
                GlassChip(title: "1km", isSelected: true, action: {})
                GlassChip(title: "2km", isSelected: false, action: {})
            }

            GlassProgressBar(progress: 0.6, label: "3/5 Missions")
                .padding(.horizontal, 40)
        }
    }
}
