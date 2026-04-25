# Vernier

Vernier is a small macOS menu bar app for measuring pixels on screen.

## Build

1. Open `vernier.xcodeproj` in Xcode.
2. Select the `vernier` scheme.
3. Build and run with `Cmd+R`.

## Use

1. Launch Vernier.
2. Click the ruler icon in the menu bar.
3. Choose `Measure`, or set a shortcut from `Settings...`.
4. Press `Esc` to leave measurement mode.

Vernier needs Screen Recording permission so it can read the screen:

1. Open `System Settings`.
2. Go to `Privacy & Security` -> `Screen & System Audio Recording`.
3. Enable Vernier.
4. Restart the app if macOS asks.

## Running Unsigned Builds

This app is not signed, so macOS may block it the first time.

To allow it:

1. Try to open Vernier once.
2. Open `System Settings` -> `Privacy & Security`.
3. Scroll to the security message about Vernier.
4. Click `Open Anyway`.
5. Confirm with `Open`.

You can also right-click the app, choose `Open`, then confirm `Open`.
