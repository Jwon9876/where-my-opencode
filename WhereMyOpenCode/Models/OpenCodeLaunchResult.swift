import Foundation

struct OpenCodeLaunchResult: Equatable, Sendable {
    let sessionID: String
    let terminalWindowID: Int?
    let terminalSessionID: String?
    let terminalTabTTY: String?
    let terminalCustomTitle: String?
    let launchedAt: Date

    static func parse(
        sessionID: String,
        payload: String,
        launchedAt: Date = Date()
    ) -> OpenCodeLaunchResult {
        let values = KeyValuePayload.parse(payload)

        return OpenCodeLaunchResult(
            sessionID: sessionID,
            terminalWindowID: values["terminalWindowID"].flatMap(Int.init),
            terminalSessionID: KeyValuePayload.nonEmpty(values["terminalSessionID"]),
            terminalTabTTY: KeyValuePayload.nonEmpty(values["terminalTabTTY"]),
            terminalCustomTitle: KeyValuePayload.nonEmpty(values["terminalCustomTitle"]),
            launchedAt: launchedAt
        )
    }
}
