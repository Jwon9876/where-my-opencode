enum MenuBarStatus: Equatable {
    case idle
    case info(String)
    case error(String)

    var message: String? {
        switch self {
        case .idle:
            nil
        case .info(let message), .error(let message):
            message
        }
    }

    var isError: Bool {
        if case .error = self {
            return true
        }

        return false
    }
}
