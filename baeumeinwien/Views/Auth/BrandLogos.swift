import SwiftUI

struct GoogleLogoView: View {
    var body: some View {
        Image("GoogleLogo")
            .resizable()
            .scaledToFit()
    }
}

struct GitHubLogoView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Image("GitHubLogo")
            .resizable()
            .scaledToFit()
            .if(colorScheme == .dark) { view in
                view.colorInvert()
            }
    }
}

private extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

#Preview("Google Logo") {
    GoogleLogoView()
        .frame(width: 44, height: 44)
        .padding()
}

#Preview("GitHub Logo") {
    GitHubLogoView()
        .frame(width: 44, height: 44)
        .padding()
}
