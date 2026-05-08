enum TerminalSessionMatcher {
    static func record(_ values: [String: String], matches session: TrackedSession) -> Bool {
        if KeyValuePayload.nonEmpty(values["marker"]) == session.marker {
            return true
        }

        if KeyValuePayload.nonEmpty(values["terminalMarker"]) == session.marker {
            return true
        }

        if let terminalSessionID = KeyValuePayload.nonEmpty(values["terminalSessionID"]),
           let expectedSessionID = session.terminalSessionID,
           terminalSessionID == expectedSessionID {
            return true
        }

        if let terminalCustomTitle = KeyValuePayload.nonEmpty(values["terminalCustomTitle"]),
           (terminalCustomTitle == session.marker || terminalCustomTitle.hasPrefix("\(session.marker) ")) {
            return true
        }

        let terminalWindowID = values["terminalWindowID"].flatMap(Int.init)
        let terminalTabTTY = KeyValuePayload.nonEmpty(values["terminalTabTTY"])

        if let expectedWindowID = session.terminalWindowID,
           let expectedTTY = session.terminalTabTTY {
            return terminalWindowID == expectedWindowID && terminalTabTTY == expectedTTY
        }

        if let expectedTTY = session.terminalTabTTY {
            return terminalTabTTY == expectedTTY
        }

        if let expectedWindowID = session.terminalWindowID {
            return terminalWindowID == expectedWindowID
        }

        return false
    }

    static func record(_ values: [String: String], matches session: RunningTerminalSession) -> Bool {
        if KeyValuePayload.nonEmpty(values["marker"]) == session.marker {
            return true
        }

        if let terminalSessionID = KeyValuePayload.nonEmpty(values["terminalSessionID"]),
           let expectedSessionID = session.terminalSessionID,
           terminalSessionID == expectedSessionID {
            return true
        }

        let terminalWindowID = values["terminalWindowID"].flatMap(Int.init)
        let terminalTabTTY = KeyValuePayload.nonEmpty(values["terminalTabTTY"])

        if let expectedWindowID = session.terminalWindowID,
           let expectedTTY = session.terminalTabTTY {
            return terminalWindowID == expectedWindowID && terminalTabTTY == expectedTTY
        }

        if let expectedTTY = session.terminalTabTTY {
            return terminalTabTTY == expectedTTY
        }

        if let expectedWindowID = session.terminalWindowID {
            return terminalWindowID == expectedWindowID
        }

        return false
    }

    static func sortMostRecentFirst(lhs: TrackedSession, rhs: TrackedSession) -> Bool {
        if lhs.openedAt == rhs.openedAt {
            return lhs.projectName.localizedCaseInsensitiveCompare(rhs.projectName) == .orderedAscending
        }

        return lhs.openedAt > rhs.openedAt
    }
}
