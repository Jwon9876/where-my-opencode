# Where My OpenCode

A macOS menu bar companion for OpenCode sessions.

`where-my-opencode` helps you open, find, and refocus project-based OpenCode sessions across multiple projects.

It is a lightweight companion app for people who use OpenCode across multiple projects and want a faster way to get back to the right session.

## Features

- Scan a root folder for projects
- Open a project in OpenCode from the menu bar
- Track sessions launched by the app
- Show running OpenCode sessions for known projects
- Bring an existing project session back to the front
- Keep recent projects close at hand
- Choose Apple Terminal or iTerm2

## Install

Download `Where-My-OpenCode-v<version>-macOS-unsigned.zip` from the latest GitHub Release, unzip it, and move `Where My OpenCode.app` into `/Applications`.

## Requirements

- macOS
- OpenCode available as `opencode`, or a custom executable selected in Settings
- Apple Terminal or iTerm2

## First Run

Because the app is distributed without Apple Developer ID notarization, macOS may block the first launch.

If macOS says Apple cannot verify the app:

1. Click Done.
2. Open System Settings > Privacy & Security.
3. In Security, click Open Anyway for Where My OpenCode.
4. Confirm with your password or Touch ID, then click Open.

After that first approval, you can launch it like any other app.

You can also remove the download quarantine from Terminal:

```bash
xattr -dr com.apple.quarantine "/Applications/Where My OpenCode.app"
open "/Applications/Where My OpenCode.app"
```

macOS may ask for Automation permission so Where My OpenCode can control your chosen terminal. It may also ask for folder access when you choose a root folder to scan.

## Status

Where My OpenCode is an early preview. It currently focuses on project discovery, app-launched session tracking, live session detection, and terminal window focusing.

## License

MIT. See [LICENSE](LICENSE).
