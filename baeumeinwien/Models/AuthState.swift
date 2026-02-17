import Foundation

enum AuthState: Equatable {
    case loading
    case notAuthenticated
    case authenticated(userId: String, email: String?, displayName: String?, avatarUrl: String?)
    case error(message: String)

    var isAuthenticated: Bool {
        if case .authenticated = self { return true }
        return false
    }

    var userId: String? {
        if case .authenticated(let userId, _, _, _) = self { return userId }
        return nil
    }

    var displayName: String? {
        if case .authenticated(_, _, let name, _) = self { return name }
        return nil
    }

    var email: String? {
        if case .authenticated(_, let email, _, _) = self { return email }
        return nil
    }
}
