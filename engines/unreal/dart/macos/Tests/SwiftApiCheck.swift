import Cocoa

// Mirrors every UnrealBridge call site in UnrealEngineController.swift.
// If NS_SWIFT_NAME in UnrealBridge.h drifts, this stops compiling.
func exerciseBridge(controller: NSObject) {
    let ok: Bool = UnrealBridge.shared.create(config: ["a": 1], controller: controller)
    _ = ok
    let view: NSView? = UnrealBridge.shared.getView()
    _ = view
    UnrealBridge.shared.pause()
    UnrealBridge.shared.resume()
    UnrealBridge.shared.quit()
    UnrealBridge.shared.sendMessage(target: "T", method: "M", data: "{}")
    UnrealBridge.shared.executeConsoleCommand("stat fps")
    UnrealBridge.shared.loadLevel("Arena")
    UnrealBridge.shared.applyQualitySettings(["qualityLevel": 3])
    let q: [AnyHashable: Any] = UnrealBridge.shared.getQualitySettings()
    _ = q
}
