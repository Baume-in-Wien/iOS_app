import SwiftUI

struct InfoView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                VStack(alignment: .center, spacing: 16) {
                    Image("AppIcon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100, height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .shadow(radius: 10)

                    Text("Bäume in Wien – iOS")
                        .font(.hostGrotesk(.title))
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)

                    Text("Version 1.6")
                        .font(.hostGrotesk(.subheadline))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 16)

                Text("Bäume in Wien ist eine moderne, unabhängige und Open-Source-App zur Erkundung des öffentlichen Baumbestands der Stadt Wien. Die App verwendet Baumkataster Daten der Stadt Wien.")
                    .font(.hostGrotesk())

                Text("Die App macht die offiziellen Open Government Data der Stadt Wien einfach zugänglich und visualisiert über 230.000 Bäume direkt auf der Karte. Ideal für Neugierige, Naturinteressierte, Schulen und den Biologie-Unterricht.")
                    .font(.hostGrotesk())

                SectionHeader(title: "🌳 Funktionen")
                VStack(alignment: .leading, spacing: 8) {
                    FeatureRow(text: "Interaktive Karte mit allen öffentlichen Bäumen Wiens")
                    FeatureRow(text: "Anzeige von Baumart, Pflanzjahr, Stammumfang, Höhe und weiteren Details")
                    FeatureRow(text: "Schnelle Suche nach Straße, Baumart oder Bezirk")
                    FeatureRow(text: "Standortbasierte Anzeige von Bäumen in deiner Umgebung")
                    FeatureRow(text: "Favoriten & lokale Notizen zu einzelnen Bäumen")
                    FeatureRow(text: "Optionaler AR-Modus zur Entdeckung von Bäumen in deiner Nähe")
                    FeatureRow(text: "Offline-fähig (nach einmaligem Laden der Daten)")
                }

                SectionHeader(title: "🧪 Bildung & Schule")
                Text("Die App eignet sich besonders für den Einsatz im Unterricht:")
                    .font(.hostGrotesk(.subheadline))
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 8) {
                    FeatureRow(text: "Natur- und Biologieunterricht")
                    FeatureRow(text: "Stadterkundung & Umweltbildung")
                    FeatureRow(text: "Projekt- und Rallye-Formate (z. B. Bäume finden, bestimmen und dokumentieren)")
                }

                SectionHeader(title: "🔓 Open Data & Open Source")
                VStack(alignment: .leading, spacing: 8) {
                    Text("Datenquelle: Stadt Wien – data.wien.gv.at (Baumkataster)")
                    Text("Lizenz der Daten: Creative Commons Namensnennung 4.0 (CC BY 4.0)")
                    Text("Open-Source-Projekt: Der Quellcode ist öffentlich einsehbar, lern- und weiterverwendbar")
                }
                .font(.hostGrotesk(.subheadline))

                VStack(alignment: .leading, spacing: 8) {
                    Text("⚠️ Hinweis:")
                        .fontWeight(.bold)
                    Text("Diese App ist nicht offiziell von der Stadt Wien. Es handelt sich um ein unabhängiges Open-Source-Projekt auf Basis öffentlich verfügbarer Daten.")
                }
                .padding()
                .background(Color.yellow.opacity(0.1))
                .cornerRadius(12)

                SectionHeader(title: "🔐 Datenschutz & Privatsphäre")
                VStack(alignment: .leading, spacing: 8) {
                    FeatureRow(text: "Keine Registrierung notwendig")
                    FeatureRow(text: "Keine Werbung")
                    FeatureRow(text: "Kein Tracking, keine Analytics")
                    FeatureRow(text: "Keine Weitergabe von Daten")
                    FeatureRow(text: "Alle Notizen & Favoriten bleiben lokal auf deinem Gerät")
                }

                Text("Die App benötigt nur:")
                    .font(.hostGrotesk(.subheadline))
                    .fontWeight(.medium)
                    .padding(.top, 8)
                VStack(alignment: .leading, spacing: 8) {
                    FeatureRow(text: "Internetzugang zum Laden der öffentlichen Baumdaten")
                    FeatureRow(text: "Optional Standortzugriff für Umkreis- und AR-Funktionen")
                }

                SectionHeader(title: "🛠 Technologie (iOS)")
                VStack(alignment: .leading, spacing: 8) {
                    FeatureRow(text: "Native iOS-App")
                    FeatureRow(text: "Swift & SwiftUI")
                    FeatureRow(text: "Apple Maps / OpenStreetMap")
                    FeatureRow(text: "Lokale Datenbank")
                    FeatureRow(text: "Fokus auf Performance & Energieeffizienz")
                }

                VStack(alignment: .center, spacing: 8) {
                    Text("❤️ Entwickelt mit Liebe für Wien")
                        .fontWeight(.semibold)
                    Text("Bäume in Wien ist ein Community-Projekt mit dem Ziel, Natur im urbanen Raum sichtbar und erlebbar zu machen.")
                    Text("Mit ❤️ von Paulify Dev entwickelt")
                        .multilineTextAlignment(.center)
                        .font(.hostGrotesk(.footnote))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 32)
                .padding(.bottom, 16)
            }
            .padding()
        }
        .navigationTitle("Info")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.hostGrotesk(.title3))
            .fontWeight(.bold)
            .padding(.top, 8)
    }
}

struct FeatureRow: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "circle.fill")
                .font(.system(size: 6))
                .padding(.top, 6)
                .foregroundStyle(.secondary)
            Text(text)
                .font(.hostGrotesk(.subheadline))
        }
    }
}

#Preview {
    InfoView()
}
