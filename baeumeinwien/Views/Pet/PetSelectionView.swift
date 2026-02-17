import SwiftUI

struct PetSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable private var petService = PetService.shared
    @State private var selectedSpecies: PetSpecies?
    @State private var showNameInput = false
    @State private var petName = ""
    @State private var showNewPetAnimation = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {

                    progressHeader

                    if !petService.allPets.isEmpty {
                        existingPetsSection
                    }

                    availableSpeciesSection

                    lockedSpeciesSection

                    Spacer(minLength: 100)
                }
                .padding()
            }
            .navigationTitle("Meine Tiere")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showNameInput) {
                nameInputSheet
            }
            .overlay {
                if showNewPetAnimation {
                    newPetCelebration
                }
            }
            .onAppear {

                if !petService.unlockedSpecies.contains(.squirrel) {
                    petService.unlockedSpecies.insert(.squirrel)
                    petService.saveData()
                }
            }
        }
    }

    private var progressHeader: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "tree.fill")
                    .foregroundStyle(.green)
                Text("\(petService.discoveredTreeCount) Bäume entdeckt")
                    .font(.hostGrotesk(.headline, weight: .semibold))
            }

            let (nextSpecies, progress) = petService.progressToNextSpecies()
            if let next = nextSpecies {
                VStack(spacing: 8) {
                    HStack {
                        Text("Nächstes Tier:")
                            .font(.hostGrotesk(.caption))
                            .foregroundStyle(.secondary)

                        Text("\(next.emoji) \(next.displayName)")
                            .font(.caption.bold())

                        Spacer()

                        Text("\(petService.discoveredTreeCount)/\(next.requiredTreesToUnlock)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }

                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.2))

                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    LinearGradient(
                                        colors: [.green, .green.opacity(0.7)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geometry.size.width * progress)
                        }
                    }
                    .frame(height: 8)
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var existingPetsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Meine Tiere")
                .font(.hostGrotesk(.headline, weight: .semibold))

            ForEach(petService.allPets, id: \.id) { pet in
                existingPetRow(pet)
            }
        }
    }

    @ViewBuilder
    private func existingPetRow(_ pet: Pet) -> some View {
        let isActive = petService.currentPet?.id == pet.id

        Button {
            petService.switchToPet(pet)
        } label: {
            HStack(spacing: 12) {

                ZStack {
                    Circle()
                        .fill(pet.species.color.opacity(0.2))
                        .frame(width: 50, height: 50)

                    Text(pet.species.emoji)
                        .font(.hostGrotesk(.title2))
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(pet.name)
                            .font(.hostGrotesk(.headline, weight: .semibold))

                        if isActive {
                            Text("Aktiv")
                                .font(.hostGrotesk(.caption2))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.green, in: Capsule())
                                .foregroundStyle(.white)
                        }
                    }

                    Text("Level \(pet.level) \(pet.species.displayName)")
                        .font(.hostGrotesk(.caption))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isActive {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isActive ? pet.species.color.opacity(0.1) : Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isActive ? pet.species.color : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    private var availableSpeciesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Neues Tier erstellen")
                .font(.hostGrotesk(.headline, weight: .semibold))

            let unlockedWithoutPets = petService.unlockedSpecies.filter { species in
                !petService.allPets.contains { $0.species == species }
            }

            if unlockedWithoutPets.isEmpty && petService.unlockedSpecies.count > 0 {
                Text("Du kannst auch ein weiteres Tier der gleichen Art erstellen!")
                    .font(.hostGrotesk(.caption))
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 8)
            }

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(Array(petService.unlockedSpecies).sorted(by: { $0.requiredTreesToUnlock < $1.requiredTreesToUnlock }), id: \.self) { species in
                    speciesCard(species, isLocked: false)
                }
            }
        }
    }

    private var lockedSpeciesSection: some View {
        let lockedSpecies = PetSpecies.allCases.filter { !petService.unlockedSpecies.contains($0) }

        return Group {
            if !lockedSpecies.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Noch nicht freigeschaltet")
                        .font(.hostGrotesk(.headline, weight: .semibold))
                        .foregroundStyle(.secondary)

                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        ForEach(lockedSpecies.sorted(by: { $0.requiredTreesToUnlock < $1.requiredTreesToUnlock }), id: \.self) { species in
                            speciesCard(species, isLocked: true)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func speciesCard(_ species: PetSpecies, isLocked: Bool) -> some View {
        Button {
            if !isLocked {
                selectedSpecies = species
                petName = species.defaultNickname
                showNameInput = true
            }
        } label: {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(species.color.opacity(isLocked ? 0.1 : 0.2))
                        .frame(width: 60, height: 60)

                    if isLocked {
                        Image(systemName: "lock.fill")
                            .foregroundStyle(.secondary)
                    } else {
                        Text(species.emoji)
                            .font(.hostGrotesk(.title))
                    }
                }

                Text(species.displayName)
                    .font(.subheadline.bold())
                    .foregroundStyle(isLocked ? .secondary : .primary)

                if isLocked {
                    Text("\(species.requiredTreesToUnlock) Bäume")
                        .font(.hostGrotesk(.caption2))
                        .foregroundStyle(.secondary)
                } else {
                    Text("Tippen zum Erstellen")
                        .font(.hostGrotesk(.caption2))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isLocked ? Color(.systemGray6) : species.color.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isLocked ? Color.clear : species.color.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isLocked)
        .opacity(isLocked ? 0.6 : 1)
    }

    private var nameInputSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if let species = selectedSpecies {

                    ZStack {
                        Circle()
                            .fill(species.color.opacity(0.2))
                            .frame(width: 100, height: 100)

                        Text(species.emoji)
                            .font(.system(size: 50))
                    }

                    Text("Wie soll dein \(species.displayName) heißen?")
                        .font(.hostGrotesk(.headline, weight: .semibold))

                    TextField("Name eingeben", text: $petName)
                        .textFieldStyle(.roundedBorder)
                        .font(.hostGrotesk(.title3))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)

                    Button {
                        createPet()
                    } label: {
                        Text("Erstellen")
                            .font(.hostGrotesk(.headline, weight: .semibold))
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(.green, in: RoundedRectangle(cornerRadius: 12))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 40)
                    .disabled(petName.trimmingCharacters(in: .whitespaces).isEmpty)
                }

                Spacer()
            }
            .padding(.top, 40)
            .navigationTitle("Neues Tier")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Abbrechen") {
                        showNameInput = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private var newPetCelebration: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                if let species = selectedSpecies {
                    Text("🎉")
                        .font(.system(size: 60))

                    Text("\(petName) ist da!")
                        .font(.title.bold())

                    Text(species.emoji)
                        .font(.system(size: 80))

                    Text(species.description)
                        .font(.hostGrotesk(.subheadline))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    Button {
                        showNewPetAnimation = false
                        dismiss()
                    } label: {
                        Text("Los geht's!")
                            .font(.hostGrotesk(.headline, weight: .semibold))
                            .padding()
                            .frame(width: 200)
                            .background(.green, in: RoundedRectangle(cornerRadius: 12))
                            .foregroundStyle(.white)
                    }
                }
            }
            .padding(30)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
            .padding()
        }
        .transition(.opacity.combined(with: .scale))
    }

    private func createPet() {
        guard let species = selectedSpecies else { return }

        let trimmedName = petName.trimmingCharacters(in: .whitespaces)
        let name = trimmedName.isEmpty ? species.defaultNickname : trimmedName

        _ = petService.createPet(species: species, name: name)

        showNameInput = false

        withAnimation(.spring()) {
            showNewPetAnimation = true
        }

        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
}

#Preview {
    PetSelectionView()
}
