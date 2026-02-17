import SwiftUI

struct PetMiniGameView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable private var petService = PetService.shared

    @State private var gameState: GameState = .ready
    @State private var score = 0
    @State private var timeRemaining = 30
    @State private var leaves: [FallingLeaf] = []
    @State private var petPosition: CGFloat = 0.5
    @State private var showCaughtEffect = false
    @State private var timer: Timer?
    @State private var spawnTimer: Timer?

    enum GameState {
        case ready
        case playing
        case finished
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack {

                    LinearGradient(
                        colors: [
                            Color.cyan.opacity(0.3),
                            Color.green.opacity(0.2)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()

                    backgroundTrees

                    switch gameState {
                    case .ready:
                        readyView
                    case .playing:
                        gameView(geometry: geometry)
                    case .finished:
                        finishedView
                    }
                }
            }
            .navigationTitle("Blätter Fangen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Schließen") {
                        stopGame()
                        dismiss()
                    }
                }
            }
        }
    }

    private var readyView: some View {
        VStack(spacing: 24) {
            Spacer()

            if let pet = petService.currentPet {
                PetAnimationView(pet: pet)
                    .frame(width: 120, height: 120)

                Text(pet.name)
                    .font(.title2.bold())
            }

            VStack(spacing: 8) {
                Text("🍂 Blätter Fangen 🍂")
                    .font(.title.bold())

                Text("Bewege dein Tier nach links und rechts\num fallende Blätter zu fangen!")
                    .font(.hostGrotesk(.subheadline))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()

            Button {
                startGame()
            } label: {
                Text("Spielen")
                    .font(.hostGrotesk(.headline, weight: .semibold))
                    .padding()
                    .frame(width: 200)
                    .background(.green, in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(.white)
            }

            Spacer()
        }
    }

    @ViewBuilder
    private func gameView(geometry: GeometryProxy) -> some View {
        let width = geometry.size.width
        let height = geometry.size.height

        ZStack {

            ForEach(leaves) { leaf in
                Text(leaf.emoji)
                    .font(.system(size: 40))
                    .rotationEffect(.degrees(leaf.rotation))
                    .position(x: leaf.x * width, y: leaf.y * height)
            }

            if showCaughtEffect {
                Text("+10")
                    .font(.title.bold())
                    .foregroundStyle(.green)
                    .position(x: petPosition * width, y: height - 150)
                    .transition(.scale.combined(with: .opacity))
            }

            VStack {
                Spacer()

                if let pet = petService.currentPet {
                    PetAnimationView(pet: pet)
                        .frame(width: 80, height: 80)
                        .position(x: petPosition * width, y: height - 80)
                }
            }

            VStack {
                HStack {

                    HStack(spacing: 4) {
                        Image(systemName: "leaf.fill")
                            .foregroundStyle(.green)
                        Text("\(score)")
                            .font(.title2.bold().monospacedDigit())
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.regularMaterial, in: Capsule())

                    Spacer()

                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .foregroundStyle(.orange)
                        Text("\(timeRemaining)s")
                            .font(.title2.bold().monospacedDigit())
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.regularMaterial, in: Capsule())
                }
                .padding()

                Spacer()
            }
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    petPosition = value.location.x / width
                    petPosition = max(0.1, min(0.9, petPosition))
                }
        )
        .onAppear {
            startGameTimers()
        }
    }

    private var finishedView: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 16) {
                Text("🎉")
                    .font(.system(size: 60))

                Text("Geschafft!")
                    .font(.title.bold())

                HStack(spacing: 8) {
                    Image(systemName: "leaf.fill")
                        .foregroundStyle(.green)
                        .font(.hostGrotesk(.title))

                    Text("\(score)")
                        .font(.system(size: 48, weight: .bold))

                    Text("Blätter")
                        .font(.hostGrotesk(.title2))
                        .foregroundStyle(.secondary)
                }

                let bonusXP = min(score / 2, 50)
                Text("+\(bonusXP) XP für dein Tier!")
                    .font(.hostGrotesk(.headline, weight: .semibold))
                    .foregroundStyle(.green)
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
            .padding()

            VStack(spacing: 12) {
                Button {
                    resetGame()
                    startGame()
                } label: {
                    Label("Nochmal spielen", systemImage: "arrow.clockwise")
                        .font(.hostGrotesk(.headline, weight: .semibold))
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(.green, in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.white)
                }

                Button {
                    dismiss()
                } label: {
                    Text("Fertig")
                        .font(.hostGrotesk(.headline, weight: .semibold))
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color(.systemGray5), in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.primary)
                }
            }
            .padding(.horizontal, 40)

            Spacer()
        }
    }

    private var backgroundTrees: some View {
        HStack(spacing: 0) {
            ForEach(0..<5, id: \.self) { i in
                Image(systemName: "tree.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.green.opacity(0.3))
                    .offset(y: CGFloat(i % 2) * 20)
            }
        }
        .frame(maxWidth: .infinity)
        .offset(y: -100)
    }

    private func startGame() {
        gameState = .playing
        score = 0
        timeRemaining = 30
        leaves = []
        petPosition = 0.5
    }

    private func startGameTimers() {

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if timeRemaining > 0 {
                timeRemaining -= 1
            } else {
                endGame()
            }
        }

        spawnTimer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { _ in
            spawnLeaf()
            updateLeaves()
        }
    }

    private func spawnLeaf() {
        let leaf = FallingLeaf(
            id: UUID(),
            x: CGFloat.random(in: 0.1...0.9),
            y: -0.1,
            rotation: Double.random(in: 0...360),
            emoji: ["🍂", "🍁", "🌿", "☘️"].randomElement()!,
            speed: Double.random(in: 0.015...0.025)
        )
        leaves.append(leaf)
    }

    private func updateLeaves() {

        for i in leaves.indices.reversed() {
            leaves[i].y += leaves[i].speed
            leaves[i].rotation += 2

            let petX = petPosition
            let leafX = leaves[i].x
            let leafY = leaves[i].y

            if leafY > 0.75 && leafY < 0.9 && abs(leafX - petX) < 0.1 {

                score += 10
                leaves.remove(at: i)

                withAnimation(.spring()) {
                    showCaughtEffect = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showCaughtEffect = false
                }

                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()

                continue
            }

            if leaves[i].y > 1.1 {
                leaves.remove(at: i)
            }
        }
    }

    private func endGame() {
        stopGame()
        gameState = .finished

        petService.onMiniGamePlayed(score: score)
    }

    private func stopGame() {
        timer?.invalidate()
        timer = nil
        spawnTimer?.invalidate()
        spawnTimer = nil
    }

    private func resetGame() {
        stopGame()
        score = 0
        timeRemaining = 30
        leaves = []
        petPosition = 0.5
    }
}

struct FallingLeaf: Identifiable {
    let id: UUID
    var x: CGFloat
    var y: CGFloat
    var rotation: Double
    let emoji: String
    let speed: Double
}

#Preview {
    PetMiniGameView()
}
