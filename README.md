# Quay

Quay is a personal macOS menu-bar app. It keeps a floating dock along the bottom of the main screen: app icons you can launch, collections of apps under one mark, and three widgets. There is no account, no analytics, and no network access.

**Version 0.1.0 was run on a Mac.** Auto-hide in 0.1.1 was added after that, and this environment has no Xcode, so the slide animation itself has not been watched here. Logic that does not need AppKit lives in `QuayCore` and is what `swift test` runs.

## Features

- **Dock bar.** A borderless panel at the bottom center of the main display, above normal windows and on every Space. It has no Dock icon of its own (`LSUIElement`). A menu-bar item opens Settings and quits. Click an app icon to launch or activate it. The layout is saved in `~/Library/Application Support/Quay/dock.json`.
- **Auto-hide.** On by default. Settings → Dock has “Automatically hide and show the dock”. Quay then leaves a 3-point strip on the bottom edge of the main display, only as wide as the dock. The pointer entering that strip slides the dock up in about 0.28 seconds. Leaving the dock, and any popover or sheet opened from it, slides it away after 0.6 seconds. Moving back during that pause cancels the hide. The rest of the bottom edge still belongs to the system Dock. The choice is saved in `dock.json`.
- **Now Playing.** Title and artist for Spotify and Music, plus previous, play/pause, and next. State comes from the distributed notifications `com.spotify.client.PlaybackStateChanged` and `com.apple.Music.playerInfo`. Transport and a one-shot refresh use AppleScript (`osascript`). Artwork is read locally from the player when that script returns image data. Quay does not call the network for cover art.
- **Collections.** One slot holds several apps under a stacked mark and a name. Clicking it opens a list; clicking an app launches it. Collections are edited in Settings.
- **Timer and stopwatch.** Countdown with 1, 5, 15, and 25 minute presets, a custom length, and a stopwatch with start, pause, and reset. The clock ticks only while one of them is running. When a countdown hits zero, Quay plays the Glass sound and posts a local notification.
- **Upcoming.** The next calendar events and due reminders, refreshed when EventKit posts `EKEventStoreChanged`. Permission uses `requestFullAccessToEvents` and `requestFullAccessToReminders`. If access is denied, the widget offers a button that opens System Settings.

Each widget kind can appear once. Reorder slots in Settings.

## Build and run

1. Install Xcode 15 or newer so the macOS 14 SDK is available. Xcode 16 is a comfortable match for this project.
2. Open `Quay.xcodeproj`. There is no generate step.
3. Select the **Quay** target, then **Signing & Capabilities**. Set **Team** to your Personal Team. Leave the bundle identifier as `com.kirill.quay`.
4. Run (⌘R).

Quay does not show a Dock icon. After it launches, use the quay mark in the menu bar. With auto-hide on, hover the thin strip at the bottom center of the main display and the dock slides up just above the system Dock; move the pointer away and it hides. Settings is the first item in the menu-bar menu. The version shown in About is 0.1.1 (build 2). Show Dock in the menu bar brings it back if you cannot find the strip.

The app is not sandboxed. That keeps Apple Events, Calendar, and Reminders on a Personal Team development signature. Hardened Runtime is turned on. The entitlements file contains `com.apple.security.automation.apple-events`.

If Xcode refuses to sign because that entitlement is not in the provisioning profile, delete the key from `App/Quay.entitlements` and run again. A non-sandboxed app still gets the Automation prompt from `NSAppleEventsUsageDescription`.

## First-launch permission prompts

| Prompt | When | Why |
| --- | --- | --- |
| Automation — Spotify | Launch, if the Now Playing widget is on the dock | Read the current track and send play, pause, and skip |
| Automation — Music | Launch, same widget | Same, for the Music app |
| Calendars (full access) | Launch, if the Upcoming widget is on the dock | Read upcoming events |
| Reminders (full access) | Launch, same widget | Read due reminders |
| Notifications | The first time you start a countdown | Show an alert when the timer finishes |

The default dock includes all three widgets, so the Automation, Calendars, and Reminders prompts are the ones to expect on a fresh launch. Notifications waits until a countdown starts. If a prompt is denied, that widget stays on the dock and explains how to turn access back on.

Reset them for this bundle id:

```sh
tccutil reset AppleEvents com.kirill.quay
tccutil reset Calendar com.kirill.quay
tccutil reset Reminders com.kirill.quay
tccutil reset Notifications com.kirill.quay
```

`tccutil` needs to be run from a Terminal that is allowed to change privacy settings. On some macOS versions the notifications service name is `UserNotifications` if `Notifications` is rejected.

## Tests

From the repository root, with a Swift toolchain available:

```sh
swift test --package-path QuayCore
```

That builds and tests timer and stopwatch state, dock and collection edits, auto-hide show/hide rules, JSON persistence, playback-notification parsing, and the agenda sort. It does not compile the app target. With Swift 6.2.4 on Linux the suite is 44 tests, all passing.

## Layout of the code

`QuayCore` is a Swift package with no Apple SDK dependencies, so it builds on Linux. The app target links that library and holds the SwiftUI, AppKit, EventKit, UserNotifications, and AppleScript code.

## Known limitations

- 0.1.0 was compiled and run in Xcode. The auto-hide slide in 0.1.1 has not been watched in this environment. The project file was written by hand.
- Browser and other system audio is not shown. Spotify and Music publish distributed notifications Quay can observe. Safari, Chrome, and other players do not. Covering them would mean the private MediaRemote framework, or a per-browser integration. Neither is part of 0.1.0, and Quay does not link MediaRemote.
- Artwork appears only when AppleScript returns a `«data …»` image. If a player returns something else, the widget shows a monogram and the transport buttons still work.
- Now Playing does not poll. It refreshes once when the widget is added and then on each player notification. A track that was already playing may show up only after that first AppleScript snapshot.
- The timer alert is delivered while Quay is running. Quitting the app stops the countdown. A running countdown's end date is saved, and the alert fires on the next launch if the time has already passed.
- The dock is fixed to the main display (the screen that owns the menu bar). Auto-hide does not hide the system Dock; the hit strip covers only Quay’s width at the bottom edge. Slots are reordered in Settings, not by dragging on the bar.
- A very full dock can grow wider than the screen. Remove or reorder slots in Settings.
- There is no weather and no theme picker.

## Version

`VERSION`, `MARKETING_VERSION`, and the About page are **0.1.1**. `CURRENT_PROJECT_VERSION` is **2**.
