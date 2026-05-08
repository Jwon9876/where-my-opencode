# Changelog

## 0.2.1 - 2026-05-08

- Improves Terminal and iTerm2 window focusing reliability.
- Fixes project clicks to focus only one matching live session before falling back to a new session.
- Refreshes the menu bar locator UI and README preview.
- Reorganizes app sources by responsibility and shares common storage, UI, and terminal session mapping code.

## 0.2.0 - 2026-05-07

- Adds a custom Where My OpenCode menu bar icon.
- Adds macOS app icon assets generated from the same icon mark.
- Shows the project icon in the README.

## 0.1.0 - Draft

Initial GitHub preview release.

- Adds a macOS menu bar app for opening project-based OpenCode sessions.
- Supports Apple Terminal and iTerm2.
- Tracks sessions launched by Where My OpenCode and shows live running sessions.
- Focuses existing app-launched sessions by project or opens a new session on demand.
- Includes a local release script for unsigned ZIP packaging with first-run Gatekeeper guidance.
