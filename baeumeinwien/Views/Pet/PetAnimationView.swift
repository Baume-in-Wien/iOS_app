import SwiftUI

struct PetAnimationView: View {
    let pet: Pet
    var isPetting: Bool = false

    @State private var bounceOffset: CGFloat = 0
    @State private var rotationAngle: Double = 0
    @State private var eyesClosed = false

    var body: some View {
        ZStack {

            Ellipse()
                .fill(Color.black.opacity(0.1))
                .frame(width: 80, height: 20)
                .offset(y: 60)
                .scaleEffect(x: 1 - (bounceOffset / 100))

            petBody
                .offset(y: bounceOffset)
                .rotationEffect(.degrees(rotationAngle))
        }
        .onAppear {
            startIdleAnimation()
        }
        .onChange(of: isPetting) { _, newValue in
            if newValue {
                performPetAnimation()
            }
        }
    }

    @ViewBuilder
    private var petBody: some View {
        ZStack {

            switch pet.species {
            case .squirrel:
                squirrelBody
            case .hedgehog:
                hedgehogBody
            case .owl:
                owlBody
            case .robin:
                robinBody
            case .butterfly:
                butterflyBody
            case .ladybug:
                ladybugBody
            }
        }
    }

    private var squirrelBody: some View {
        ZStack {

            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [.orange.opacity(0.8), .brown],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 40, height: 70)
                .rotationEffect(.degrees(-30))
                .offset(x: -35, y: -10)

            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [.orange, .brown.opacity(0.8)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 60, height: 80)

            Ellipse()
                .fill(Color.white.opacity(0.9))
                .frame(width: 35, height: 50)
                .offset(y: 5)

            Circle()
                .fill(
                    LinearGradient(
                        colors: [.orange, .brown.opacity(0.7)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 50, height: 50)
                .offset(y: -45)

            ForEach([(-15, -65), (15, -65)], id: \.0) { offset in
                Ellipse()
                    .fill(Color.orange)
                    .frame(width: 12, height: 20)
                    .offset(x: CGFloat(offset.0), y: CGFloat(offset.1))
            }

            eyes.offset(y: -45)

            Circle()
                .fill(Color.black)
                .frame(width: 8, height: 8)
                .offset(y: -35)

            evolutionIndicator
        }
        .scaleEffect(evolutionScale)
    }

    private var hedgehogBody: some View {
        ZStack {

            ForEach(0..<12, id: \.self) { i in
                Capsule()
                    .fill(Color.brown)
                    .frame(width: 8, height: 30)
                    .offset(y: -35)
                    .rotationEffect(.degrees(Double(i) * 30 - 165))
            }

            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [.brown, .brown.opacity(0.7)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 80, height: 60)

            Ellipse()
                .fill(Color(red: 0.8, green: 0.7, blue: 0.6))
                .frame(width: 45, height: 40)
                .offset(x: 20, y: 5)

            Circle()
                .fill(eyesClosed ? Color.black : Color.white)
                .frame(width: 12, height: 12)
                .offset(x: 25, y: -5)
                .overlay(
                    Circle()
                        .fill(Color.black)
                        .frame(width: 6, height: 6)
                        .offset(x: 25, y: -5)
                        .opacity(eyesClosed ? 0 : 1)
                )

            Ellipse()
                .fill(Color.black)
                .frame(width: 10, height: 8)
                .offset(x: 40, y: 5)
        }
        .scaleEffect(evolutionScale)
    }

    private var owlBody: some View {
        ZStack {

            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [.purple.opacity(0.6), .brown],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 70, height: 90)

            ForEach(0..<5, id: \.self) { i in
                Capsule()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 40, height: 8)
                    .offset(y: CGFloat(i * 12) - 10)
            }

            Circle()
                .fill(
                    LinearGradient(
                        colors: [.purple.opacity(0.7), .brown.opacity(0.8)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 60, height: 60)
                .offset(y: -50)

            ForEach([(-20, -75), (20, -75)], id: \.0) { offset in
                Triangle()
                    .fill(Color.purple.opacity(0.6))
                    .frame(width: 20, height: 25)
                    .offset(x: CGFloat(offset.0), y: CGFloat(offset.1))
            }

            ForEach([-12, 12], id: \.self) { x in
                ZStack {
                    Circle()
                        .fill(Color.yellow)
                        .frame(width: 22, height: 22)

                    Circle()
                        .fill(Color.black)
                        .frame(width: eyesClosed ? 22 : 10, height: eyesClosed ? 2 : 10)
                }
                .offset(x: CGFloat(x), y: -55)
            }

            Triangle()
                .fill(Color.orange)
                .frame(width: 12, height: 15)
                .rotationEffect(.degrees(180))
                .offset(y: -38)
        }
        .scaleEffect(evolutionScale)
    }

    private var robinBody: some View {
        ZStack {

            Ellipse()
                .fill(Color.brown)
                .frame(width: 20, height: 40)
                .offset(x: -30, y: 20)
                .rotationEffect(.degrees(-20))

            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [.brown, .brown.opacity(0.6)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 50, height: 60)

            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [.red, .red.opacity(0.7)],
                        center: .center,
                        startRadius: 5,
                        endRadius: 25
                    )
                )
                .frame(width: 35, height: 40)
                .offset(y: 5)

            Circle()
                .fill(Color.brown)
                .frame(width: 35, height: 35)
                .offset(y: -35)

            Circle()
                .fill(eyesClosed ? Color.black : Color.white)
                .frame(width: 10, height: 10)
                .offset(x: 5, y: -38)
                .overlay(
                    Circle()
                        .fill(Color.black)
                        .frame(width: 5, height: 5)
                        .offset(x: 5, y: -38)
                        .opacity(eyesClosed ? 0 : 1)
                )

            Triangle()
                .fill(Color.orange)
                .frame(width: 8, height: 12)
                .rotationEffect(.degrees(90))
                .offset(x: 20, y: -35)
        }
        .scaleEffect(evolutionScale)
    }

    private var butterflyBody: some View {
        ZStack {

            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [.blue, .purple, .blue.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 50, height: 70)
                .rotationEffect(.degrees(-20))
                .offset(x: -30)

            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [.blue, .purple, .blue.opacity(0.7)],
                        startPoint: .topTrailing,
                        endPoint: .bottomLeading
                    )
                )
                .frame(width: 50, height: 70)
                .rotationEffect(.degrees(20))
                .offset(x: 30)

            ForEach([-30, 30], id: \.self) { x in
                Circle()
                    .fill(Color.white.opacity(0.5))
                    .frame(width: 15, height: 15)
                    .offset(x: CGFloat(x), y: -10)

                Circle()
                    .fill(Color.yellow.opacity(0.6))
                    .frame(width: 10, height: 10)
                    .offset(x: CGFloat(x), y: 10)
            }

            Capsule()
                .fill(Color.black)
                .frame(width: 12, height: 60)

            Circle()
                .fill(Color.black)
                .frame(width: 18, height: 18)
                .offset(y: -35)

            ForEach([-8, 8], id: \.self) { x in
                Capsule()
                    .fill(Color.black)
                    .frame(width: 2, height: 20)
                    .offset(x: CGFloat(x), y: -50)
                    .rotationEffect(.degrees(Double(x)))

                Circle()
                    .fill(Color.black)
                    .frame(width: 5, height: 5)
                    .offset(x: CGFloat(x) + CGFloat(x > 0 ? 3 : -3), y: -60)
            }

            ForEach([-4, 4], id: \.self) { x in
                Circle()
                    .fill(Color.white)
                    .frame(width: 6, height: 6)
                    .offset(x: CGFloat(x), y: -37)
            }
        }
        .scaleEffect(evolutionScale)
    }

    private var ladybugBody: some View {
        ZStack {

            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [.red, .red.opacity(0.8)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 70, height: 80)

            Rectangle()
                .fill(Color.black)
                .frame(width: 3, height: 80)

            ForEach([(-15, -20), (15, -20), (-20, 10), (20, 10), (-12, 35), (12, 35)], id: \.0) { offset in
                Circle()
                    .fill(Color.black)
                    .frame(width: 12, height: 12)
                    .offset(x: CGFloat(offset.0), y: CGFloat(offset.1))
            }

            Circle()
                .fill(Color.black)
                .frame(width: 35, height: 35)
                .offset(y: -50)

            ForEach([-8, 8], id: \.self) { x in
                Circle()
                    .fill(Color.white)
                    .frame(width: 10, height: 10)
                    .offset(x: CGFloat(x), y: -55)

                Circle()
                    .fill(Color.black)
                    .frame(width: 5, height: 5)
                    .offset(x: CGFloat(x), y: -55)
            }

            ForEach([(-10, -70), (10, -70)], id: \.0) { offset in
                Capsule()
                    .fill(Color.black)
                    .frame(width: 3, height: 15)
                    .offset(x: CGFloat(offset.0), y: CGFloat(offset.1))
            }
        }
        .scaleEffect(evolutionScale)
    }

    private var eyes: some View {
        HStack(spacing: 12) {
            ForEach([0, 1], id: \.self) { _ in
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 14, height: 14)

                    Circle()
                        .fill(Color.black)
                        .frame(width: eyesClosed ? 14 : 6, height: eyesClosed ? 2 : 6)
                }
            }
        }
    }

    private var evolutionIndicator: some View {
        Group {
            if pet.evolutionStage == .adult {

                Image(systemName: "crown.fill")
                    .foregroundStyle(.yellow)
                    .font(.hostGrotesk(.caption))
                    .offset(y: -85)
            }
        }
    }

    private var evolutionScale: CGFloat {
        switch pet.evolutionStage {
        case .baby: return 0.7
        case .juvenile: return 0.85
        case .adult: return 1.0
        }
    }

    private func startIdleAnimation() {

        withAnimation(
            .easeInOut(duration: 1.5)
            .repeatForever(autoreverses: true)
        ) {
            bounceOffset = -5
        }

        Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            blink()
        }
    }

    private func blink() {
        eyesClosed = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            eyesClosed = false
        }
    }

    private func performPetAnimation() {

        withAnimation(.easeInOut(duration: 0.1).repeatCount(6, autoreverses: true)) {
            rotationAngle = 10
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation {
                rotationAngle = 0
            }
        }
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

#Preview {
    VStack(spacing: 40) {
        HStack(spacing: 30) {
            PetAnimationView(pet: Pet(species: .squirrel))
            PetAnimationView(pet: Pet(species: .hedgehog))
            PetAnimationView(pet: Pet(species: .owl))
        }
        HStack(spacing: 30) {
            PetAnimationView(pet: Pet(species: .robin))
            PetAnimationView(pet: Pet(species: .butterfly))
            PetAnimationView(pet: Pet(species: .ladybug))
        }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.green.opacity(0.1))
}
