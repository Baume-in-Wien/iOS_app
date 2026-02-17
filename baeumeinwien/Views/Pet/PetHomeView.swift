import SwiftUI

struct PetHomeView: View {
    @Bindable private var petService = PetService.shared
    @State private var showMiniGame = false
    @State private var showPetSelection = false
    @State private var showAccessories = false
    @State private var showFoodInventory = false
    @State private var isPetting = false
    @State private var showHearts = false
    @State private var petScale: CGFloat = 1.0
    @State private var showFeedAnimation = false
    @State private var fedFoodEmoji = ""
    @State private var refreshTrigger = false

    var body: some View {
        NavigationStack {
            Group {
                if let pet = petService.currentPet {
                    petContentView(pet)
                } else {
                    noPetView
                }
            }
            .id(refreshTrigger)
            .navigationTitle("Mein Tier")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showPetSelection = true
                        } label: {
                            Label("Tier wechseln", systemImage: "arrow.triangle.2.circlepath")
                        }

                        Button {
                            showAccessories = true
                        } label: {
                            Label("Accessoires", systemImage: "sparkles")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showMiniGame) {
                PetMiniGameView()
            }
            .sheet(isPresented: $showPetSelection) {
                PetSelectionView()
                    .onDisappear {

                        refreshTrigger.toggle()
                    }
            }
            .sheet(isPresented: $showAccessories) {
                accessoriesSheet
            }
            .sheet(isPresented: $showFoodInventory) {
                foodInventorySheet
            }
        }
    }

    @ViewBuilder
    private func petContentView(_ pet: Pet) -> some View {
        ScrollView {
            VStack(spacing: 24) {

                petDisplaySection(pet)

                foodSection

                needsSection(pet)

                if let treeName = pet.homeTreeName {
                    homeSection(treeName)
                }

                actionsSection(pet)

                levelSection(pet)

                Spacer(minLength: 100)
            }
            .padding()
        }
        .background(
            LinearGradient(
                colors: [
                    Color.green.opacity(0.1),
                    Color.blue.opacity(0.05),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }

    @ViewBuilder
    private func petDisplaySection(_ pet: Pet) -> some View {
        VStack(spacing: 16) {

            HStack {
                Spacer()
                Text("Level \(pet.level)")
                    .font(.caption.bold())
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(pet.species.color.opacity(0.2), in: Capsule())
                    .foregroundStyle(pet.species.color)
            }

            ZStack {

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                pet.species.color.opacity(0.3),
                                pet.species.color.opacity(0.1),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 20,
                            endRadius: 120
                        )
                    )
                    .frame(width: 240, height: 240)

                if showHearts {
                    ForEach(0..<5, id: \.self) { i in
                        Image(systemName: "heart.fill")
                            .foregroundStyle(.pink)
                            .font(.hostGrotesk(.title))
                            .offset(
                                x: CGFloat.random(in: -40...40),
                                y: CGFloat.random(in: -60...(-20))
                            )
                            .opacity(showHearts ? 1 : 0)
                            .animation(
                                .easeOut(duration: 1.0).delay(Double(i) * 0.1),
                                value: showHearts
                            )
                    }
                }

                PetAnimationView(pet: pet, isPetting: isPetting)
                    .frame(width: 150, height: 150)
                    .scaleEffect(petScale)
                    .onTapGesture {
                        performPetting()
                    }

                if pet.equippedAccessory != .none {
                    Text(pet.equippedAccessory.emoji)
                        .font(.system(size: 40))
                        .offset(y: -70)
                }

                Text(pet.mood.emoji)
                    .font(.hostGrotesk(.title))
                    .offset(x: 60, y: -60)
            }

            VStack(spacing: 4) {
                Text(pet.name)
                    .font(.title2.bold())

                HStack(spacing: 4) {
                    Text(pet.species.emoji)
                    Text(pet.species.displayName)
                        .foregroundStyle(.secondary)
                    Text("•")
                        .foregroundStyle(.secondary)
                    Text(pet.evolutionStage.displayName)
                        .foregroundStyle(.secondary)
                }
                .font(.hostGrotesk(.subheadline))
            }
        }
    }

    @ViewBuilder
    private func needsSection(_ pet: Pet) -> some View {
        VStack(spacing: 12) {
            HStack {
                Text("Bedürfnisse")
                    .font(.hostGrotesk(.headline, weight: .semibold))
                Spacer()
            }

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(PetNeedType.allCases, id: \.self) { need in
                    PetStatusBar(
                        type: need,
                        value: pet.needValue(for: need)
                    )
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private func homeSection(_ treeName: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "tree.fill")
                .font(.hostGrotesk(.title2))
                .foregroundStyle(.green)
                .frame(width: 44, height: 44)
                .background(Color.green.opacity(0.1), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text("Wohnt bei")
                    .font(.hostGrotesk(.caption))
                    .foregroundStyle(.secondary)
                Text(treeName)
                    .font(.subheadline.bold())
            }

            Spacer()

            Image(systemName: "mappin.circle.fill")
                .foregroundStyle(.red)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private func actionsSection(_ pet: Pet) -> some View {
        VStack(spacing: 12) {
            HStack {
                Text("Aktionen")
                    .font(.hostGrotesk(.headline, weight: .semibold))
                Spacer()
            }

            HStack(spacing: 16) {

                ActionButton(
                    title: "Streicheln",
                    icon: "hand.raised.fill",
                    color: .pink
                ) {
                    performPetting()
                }

                ActionButton(
                    title: "Spielen",
                    icon: "gamecontroller.fill",
                    color: .purple
                ) {
                    showMiniGame = true
                }
            }

            Text("💡 Entdecke Bäume um dein Tier zu füttern!")
                .font(.hostGrotesk(.caption))
                .foregroundStyle(.secondary)
                .padding(.top, 8)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private func levelSection(_ pet: Pet) -> some View {
        VStack(spacing: 12) {
            HStack {
                Text("Fortschritt")
                    .font(.hostGrotesk(.headline, weight: .semibold))
                Spacer()
                Text("\(pet.experience) / \(pet.experienceToNextLevel) XP")
                    .font(.hostGrotesk(.caption))
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.2))

                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: [pet.species.color, pet.species.color.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * pet.levelProgress)
                }
            }
            .frame(height: 12)

            if pet.evolutionStage != .adult {
                let nextStage = PetEvolutionStage(rawValue: pet.evolutionStage.rawValue + 1) ?? .adult
                HStack {
                    Image(systemName: "arrow.up.circle.fill")
                        .foregroundStyle(.green)
                    Text("Nächste Entwicklung bei Level \(nextStage.requiredLevel)")
                        .font(.hostGrotesk(.caption))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var noPetView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "pawprint.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.green.opacity(0.5))

            Text("Kein Haustier")
                .font(.title2.bold())

            Text("Wähle dein erstes Tier und kümmere dich um es!")
                .font(.hostGrotesk(.subheadline))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button {
                showPetSelection = true
            } label: {
                Label("Tier auswählen", systemImage: "plus.circle.fill")
                    .font(.hostGrotesk(.headline, weight: .semibold))
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(.green, in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 40)

            Spacer()
        }
    }

    private var accessoriesSheet: some View {
        NavigationStack {
            List {
                if let pet = petService.currentPet {
                    ForEach(pet.unlockedAccessories, id: \.self) { accessory in
                        Button {
                            petService.equipAccessory(accessory)
                        } label: {
                            HStack {
                                Text(accessory.emoji.isEmpty ? "❌" : accessory.emoji)
                                    .font(.hostGrotesk(.title2))

                                Text(accessory.displayName)

                                Spacer()

                                if pet.equippedAccessory == accessory {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                }
                            }
                        }
                        .foregroundStyle(.primary)
                    }

                    Section("Noch nicht freigeschaltet") {
                        ForEach(PetAccessory.allCases.filter { !pet.unlockedAccessories.contains($0) }, id: \.self) { accessory in
                            HStack {
                                Text(accessory.emoji)
                                    .font(.hostGrotesk(.title2))
                                    .opacity(0.3)

                                Text(accessory.displayName)
                                    .foregroundStyle(.secondary)

                                Spacer()

                                Text("Level \(accessory.requiredLevel)")
                                    .font(.hostGrotesk(.caption))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Accessoires")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") {
                        showAccessories = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private var foodSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Futter")
                    .font(.hostGrotesk(.headline, weight: .semibold))

                Spacer()

                Button {
                    showFoodInventory = true
                } label: {
                    HStack(spacing: 4) {
                        Text("\(petService.foodInventory.totalCount)")
                            .font(.subheadline.bold())
                        Image(systemName: "bag.fill")
                    }
                    .foregroundStyle(.green)
                }
            }

            if petService.foodInventory.availableFood.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "leaf.arrow.triangle.circlepath")
                        .font(.hostGrotesk(.title))
                        .foregroundStyle(.secondary)

                    Text("Kein Futter vorhanden")
                        .font(.hostGrotesk(.subheadline))
                        .foregroundStyle(.secondary)

                    Text("Gehe zu Bäumen um Futter zu sammeln!")
                        .font(.hostGrotesk(.caption))
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(petService.foodInventory.availableFood.prefix(6), id: \.type.id) { item in
                            foodItemButton(item.type, count: item.count)
                        }
                    }
                }

                if showFeedAnimation {
                    Text(fedFoodEmoji)
                        .font(.system(size: 40))
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private func foodItemButton(_ food: PetFoodType, count: Int) -> some View {
        let likesFood = petService.currentPet.map { TreeFoodMapping.doesPetLike(food: food, species: $0.species) } ?? false

        Button {
            feedPetWith(food)
        } label: {
            VStack(spacing: 4) {
                ZStack(alignment: .topTrailing) {
                    Text(food.emoji)
                        .font(.system(size: 30))
                        .frame(width: 50, height: 50)
                        .background(food.color.opacity(0.15), in: Circle())

                    Text("\(count)")
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(food.color, in: Capsule())
                        .offset(x: 5, y: -5)
                }

                Text(food.displayName)
                    .font(.hostGrotesk(.caption2))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if likesFood {
                    Image(systemName: "heart.fill")
                        .font(.hostGrotesk(.caption2))
                        .foregroundStyle(.pink)
                }
            }
            .padding(8)
            .background(likesFood ? food.color.opacity(0.1) : Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(likesFood ? food.color.opacity(0.5) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var foodInventorySheet: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(.blue)
                        Text("Gehe zu Bäumen in der Karte um Futter zu sammeln!")
                            .font(.hostGrotesk(.caption))
                            .foregroundStyle(.secondary)
                    }
                }

                if petService.foodInventory.availableFood.isEmpty {
                    Section {
                        ContentUnavailableView(
                            "Kein Futter",
                            systemImage: "leaf.arrow.triangle.circlepath",
                            description: Text("Besuche verschiedene Bäume um Futter für dein Tier zu sammeln.")
                        )
                    }
                } else {
                    Section("Dein Futter") {
                        ForEach(petService.foodInventory.availableFood, id: \.type.id) { item in
                            let likesFood = petService.currentPet.map { TreeFoodMapping.doesPetLike(food: item.type, species: $0.species) } ?? false

                            Button {
                                feedPetWith(item.type)
                            } label: {
                                HStack {
                                    Text(item.type.emoji)
                                        .font(.hostGrotesk(.title2))

                                    VStack(alignment: .leading) {
                                        HStack {
                                            Text(item.type.displayName)
                                                .foregroundStyle(.primary)

                                            if likesFood {
                                                Image(systemName: "heart.fill")
                                                    .font(.hostGrotesk(.caption))
                                                    .foregroundStyle(.pink)
                                            }
                                        }

                                        Text("Nährwert: +\(Int(item.type.nutritionValue * 100))%")
                                            .font(.hostGrotesk(.caption))
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    Text("×\(item.count)")
                                        .font(.hostGrotesk(.headline, weight: .semibold))
                                        .foregroundStyle(item.type.color)

                                    Image(systemName: "chevron.right")
                                        .font(.hostGrotesk(.caption))
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                    }

                    Section("Futter-Tipps") {
                        if let pet = petService.currentPet {
                            HStack {
                                Text(pet.species.emoji)
                                    .font(.hostGrotesk(.title3))

                                VStack(alignment: .leading) {
                                    Text("\(pet.name) mag besonders:")
                                        .font(.hostGrotesk(.caption))
                                        .foregroundStyle(.secondary)

                                    Text(favoriteFoodsText(for: pet.species))
                                        .font(.hostGrotesk(.caption))
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Futter-Inventar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") {
                        showFoodInventory = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func favoriteFoodsText(for species: PetSpecies) -> String {
        let favorites = PetFoodType.allCases.filter { TreeFoodMapping.doesPetLike(food: $0, species: species) }
        return favorites.map { $0.emoji + " " + $0.displayName }.joined(separator: ", ")
    }

    private func feedPetWith(_ food: PetFoodType) {
        guard petService.feedPet(with: food) else { return }

        fedFoodEmoji = food.emoji
        withAnimation(.spring()) {
            showFeedAnimation = true
        }

        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation {
                showFeedAnimation = false
            }
        }
    }

    private func performPetting() {
        guard !isPetting else { return }

        isPetting = true
        showHearts = true

        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
            petScale = 1.15
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                petScale = 1.0
            }
        }

        petService.petAnimal()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            isPetting = false
            showHearts = false
        }
    }
}

struct ActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.hostGrotesk(.title2))
                    .frame(width: 50, height: 50)
                    .background(color.opacity(0.15), in: Circle())
                    .foregroundStyle(color)

                Text(title)
                    .font(.hostGrotesk(.caption))
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    PetHomeView()
}
