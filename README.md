# TouchMon for macOS

A lightweight, open-source macOS menu bar application designed to bring native-like gesture support and multi-display coordinate fixes to third-party touch monitors.

## The Problem
Using third-party touch screens on macOS often comes with significant limitations:
1. **Coordinate Mapping Issues:** Touches on a secondary touch monitor often mistakenly teleport the cursor to the primary screen.
2. **No Native Gestures:** Single-finger dragging acts as a text selection (drag-and-drop) rather than scrolling the page.
3. **No Right Click:** Lack of native long-press support for right-clicks.
4. Existing third-party drivers are often expensive, closed-source, and heavy.

## The Solution
TouchMon is a minimal, low-level Swift daemon that runs quietly in your menu bar. It identifies events coming exclusively from your touch monitor (ignoring your Trackpad/Mouse) and intelligently maps them to comfortable, tablet-like gestures.

### Features
- **Cross-Display Teleportation:** Automatically recalculates coordinate bounds and instantly warps the cursor to your finger, even if the OS tries to map it to the primary display.
- **Smart Scrolling:** Single-finger drag instantly scrolls pages (just like a tablet or phone).
- **Drag & Select:** Hold for `0.25s` and drag to select text or move windows.
- **Right Click:** Long press for `0.5s` and release to trigger a right-click.
- **Trackpad Protection:** Identifies devices via `Subtype`. Your normal Trackpad and Mouse will continue to function natively without interference.

## Installation & Build

No Xcode required. You can build the application directly using the included shell script.

1. Clone the repository.
2. Open your terminal and navigate to the folder.
3. Run the build script:
   ```bash
   bash build_app.sh
   ```
4. A `TouchMonitor.app` bundle will be generated in the same directory.
5. Drag `TouchMonitor.app` to your `Applications` folder and launch it.

## Permissions
TouchMon requires **Accessibility** permissions to intercept touch events and synthesize clicks. 
When you first launch the app, macOS will prompt you to grant Accessibility access in `System Settings -> Privacy & Security -> Accessibility`.

## License
This project is open-source and available under the MIT License.
