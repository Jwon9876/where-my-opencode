import Foundation

struct AppleScriptRunner {
    typealias ErrorFactory = (String) -> Error

    private let preparationFailureMessage: String
    private let executionFailureFallbackMessage: String
    private let makeError: ErrorFactory

    init(
        preparationFailureMessage: String,
        executionFailureFallbackMessage: String,
        makeError: @escaping ErrorFactory
    ) {
        self.preparationFailureMessage = preparationFailureMessage
        self.executionFailureFallbackMessage = executionFailureFallbackMessage
        self.makeError = makeError
    }

    func run(_ source: String) throws -> String {
        guard let script = NSAppleScript(source: source) else {
            throw makeError(preparationFailureMessage)
        }

        var errorInfo: NSDictionary?
        let result = script.executeAndReturnError(&errorInfo)

        if let errorInfo {
            let message = errorInfo[NSAppleScript.errorMessage] as? String
            throw makeError(message ?? executionFailureFallbackMessage)
        }

        return result.stringValue ?? ""
    }
}
