import AppKit
import CoreGraphics
import Foundation

// MARK: - Configuration
let TOUCH_SUBTYPE: Int64 = 0
let SYNTHETIC_EVENT_TAG: Int64 = 9999
let HOVER_THRESHOLD: TimeInterval = 0.25 
let RIGHT_CLICK_THRESHOLD: TimeInterval = 0.5      
let SCROLL_SPEED: CGFloat = 2.0

enum TouchState {
    case none, waiting, scrolling, selecting
}

// MARK: - Core Service
class TouchService {
    static let shared = TouchService()
    
    var isEnabled: Bool = true {
        didSet {
            if let port = tapPort {
                CGEvent.tapEnable(tap: port, enable: isEnabled)
            }
        }
    }
    
    private var tapPort: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    
    private var currentState: TouchState = .none
    private var touchStartPos: CGPoint = .zero
    private var previousPos: CGPoint = .zero
    private var touchStartTime = Date()
    
    func start() {
        let eventMask = (1 << CGEventType.leftMouseDown.rawValue) |
                        (1 << CGEventType.leftMouseDragged.rawValue) |
                        (1 << CGEventType.leftMouseUp.rawValue)
        
        tapPort = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                return TouchService.shared.handleEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: nil
        )
        
        guard let tap = tapPort else {
            print("Event tap failed. Ensure accessibility permissions are granted.")
            return
        }
        
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }
    
    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if !isEnabled { return Unmanaged.passUnretained(event) }
        
        // Ignore self-generated synthetic events to prevent infinite loops
        if event.getIntegerValueField(.eventSourceUserData) == SYNTHETIC_EVENT_TAG {
            return Unmanaged.passUnretained(event)
        }
        
        // Ignore non-touch devices (e.g. Trackpad)
        if event.getIntegerValueField(.mouseEventSubtype) != TOUCH_SUBTYPE {
            return Unmanaged.passUnretained(event)
        }
        
        let location = correctTouchLocation(event.location)
        event.location = location
        
        switch type {
        case .leftMouseDown:
            touchStartPos = location
            previousPos = location
            touchStartTime = Date()
            currentState = .waiting
            
            teleportCursor(to: location)
            return nil
            
        case .leftMouseDragged:
            if currentState == .none { return Unmanaged.passUnretained(event) }
            
            let holdDuration = Date().timeIntervalSince(touchStartTime)
            
            if currentState == .waiting {
                let distance = hypot(location.x - touchStartPos.x, location.y - touchStartPos.y)
                if distance > 5 {
                    if holdDuration < HOVER_THRESHOLD {
                        currentState = .scrolling
                    } else {
                        currentState = .selecting
                        synthesizeLeftDown(at: touchStartPos)
                    }
                }
            }
            
            if currentState == .scrolling {
                let dx = location.x - previousPos.x
                let dy = location.y - previousPos.y
                synthesizeScroll(deltaX: dx, deltaY: dy)
                teleportCursor(to: location)
                previousPos = location
                return nil
                
            } else if currentState == .selecting {
                synthesizeLeftDragged(to: location)
                previousPos = location
                return nil
            }
            return nil
            
        case .leftMouseUp:
            if currentState == .none { return Unmanaged.passUnretained(event) }
            
            let holdDuration = Date().timeIntervalSince(touchStartTime)
            
            if currentState == .waiting {
                if holdDuration >= RIGHT_CLICK_THRESHOLD {
                    synthesizeRightClick(at: touchStartPos)
                } else {
                    synthesizeLeftClick(at: touchStartPos)
                }
            } else if currentState == .selecting {
                synthesizeLeftUp(at: location)
            }
            
            currentState = .none
            return nil
            
        default:
            break
        }
        return Unmanaged.passUnretained(event)
    }
    
    // MARK: - Coordinate Mapping
    private func correctTouchLocation(_ location: CGPoint) -> CGPoint {
        var displayCount: UInt32 = 0
        CGGetActiveDisplayList(0, nil, &displayCount)
        if displayCount <= 1 { return location }
        
        var displays = [CGDirectDisplayID](repeating: 0, count: Int(displayCount))
        CGGetActiveDisplayList(displayCount, &displays, &displayCount)
        
        var activeBounds: CGRect = .zero
        var touchBounds: CGRect = .zero
        
        for display in displays {
            let bounds = CGDisplayBounds(display)
            if bounds.contains(location) { activeBounds = bounds }
            if bounds.origin != .zero { touchBounds = bounds }
        }
        
        if activeBounds == .zero || touchBounds == .zero { return location }
        if activeBounds == touchBounds { return location }
        
        let relX = (location.x - activeBounds.origin.x) / activeBounds.width
        let relY = (location.y - activeBounds.origin.y) / activeBounds.height
        
        let newX = touchBounds.origin.x + (relX * touchBounds.width)
        let newY = touchBounds.origin.y + (relY * touchBounds.height)
        return CGPoint(x: newX, y: newY)
    }
    
    // MARK: - Event Synthesis
    private func postEvent(_ event: CGEvent) {
        event.setIntegerValueField(.eventSourceUserData, value: SYNTHETIC_EVENT_TAG)
        event.post(tap: .cghidEventTap)
    }
    
    private func teleportCursor(to point: CGPoint) {
        CGWarpMouseCursorPosition(point)
        if let moved = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left) {
            postEvent(moved)
        }
    }
    
    private func synthesizeLeftClick(at point: CGPoint) {
        if let down = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left),
           let up = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left) {
            postEvent(down)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) { self.postEvent(up) }
        }
    }
    
    private func synthesizeRightClick(at point: CGPoint) {
        if let down = CGEvent(mouseEventSource: nil, mouseType: .rightMouseDown, mouseCursorPosition: point, mouseButton: .right),
           let up = CGEvent(mouseEventSource: nil, mouseType: .rightMouseUp, mouseCursorPosition: point, mouseButton: .right) {
            postEvent(down)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) { self.postEvent(up) }
        }
    }
    
    private func synthesizeScroll(deltaX: CGFloat, deltaY: CGFloat) {
        if let scroll = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 2, wheel1: Int32(deltaY * SCROLL_SPEED), wheel2: Int32(deltaX * SCROLL_SPEED), wheel3: 0) {
            postEvent(scroll)
        }
    }
    
    private func synthesizeLeftDown(at point: CGPoint) {
        if let e = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left) { postEvent(e) }
    }
    
    private func synthesizeLeftDragged(to point: CGPoint) {
        if let e = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDragged, mouseCursorPosition: point, mouseButton: .left) { postEvent(e) }
    }
    
    private func synthesizeLeftUp(at point: CGPoint) {
        if let e = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left) { postEvent(e) }
    }
}

// MARK: - App Delegate (Menu Bar Configuration)
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Request accessibility permissions if needed
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String : true]
        AXIsProcessTrustedWithOptions(options)
        
        // Create Menu Bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.title = "👆 TouchMon" 
        }
        
        let menu = NSMenu()
        let toggleItem = NSMenuItem(title: "Disable Touch", action: #selector(toggleService(_:)), keyEquivalent: "t")
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        
        menu.addItem(toggleItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(quitItem)
        
        statusItem.menu = menu
        
        TouchService.shared.start()
    }
    
    @objc func toggleService(_ sender: NSMenuItem) {
        TouchService.shared.isEnabled.toggle()
        if TouchService.shared.isEnabled {
            sender.title = "Disable Touch"
            statusItem.button?.title = "👆 TouchMon"
        } else {
            sender.title = "Enable Touch"
            statusItem.button?.title = "👆 (Off)"
        }
    }
    
    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}

// MARK: - Entry Point
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
