import Cocoa
import FlutterMacOS
import gameframework

/**
 * Unreal Engine controller for macOS.
 *
 * Subclasses the shared GameEngineController, so it answers the same method
 * channel and raises the same events as the iOS one and the Dart side does not
 * need to know which it is talking to.
 *
 * Unlike iOS this reaches the bridge directly rather than through the
 * Objective-C runtime. The bridge is pod code and always present here; on iOS
 * it has to tolerate the engine framework being missing entirely.
 */
public class UnrealEngineController: GameEngineController {

    public static let engineTypeValue = "unreal"
    public static let engineVersionValue = "5.8"

    private var unrealView: NSView?

    /// Whether unloadEngine gave the view back. Guards reload, so calling it on
    /// a running engine does nothing rather than resuming something that was
    /// never paused.
    private var isUnloaded = false

    public override var engineType: String { UnrealEngineController.engineTypeValue }
    public override var engineVersion: String { UnrealEngineController.engineVersionValue }

    public override func createEngine() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            NSLog("UnrealEngineController: Creating Unreal Engine...")

            let bridge = UnrealBridge.shared
            let config: [String: Any] = self.getConfigValue("config") ?? [:]

            guard bridge.create(config: config, controller: self) else {
                NSLog("UnrealEngineController: Failed to create Unreal Engine")
                self.sendEvent(name: "onError", data: [
                    "message": "Failed to create the Unreal engine. Is UnrealFramework linked?"
                ])
                // Ready anyway, so the app can show the error rather than wait
                // forever for a state that is never coming.
                self._isReady = true
                return
            }

            if let view = bridge.getView() {
                self.attach(view)
            } else {
                // Normal on the first call. The engine hands its view over once
                // it has built one, and the bridge offers it from the tick.
                NSLog("UnrealEngineController: Waiting for the engine's render view")
            }

            self._isReady = true
            self.sendEvent(name: "onCreated", data: nil)
            self.sendEvent(name: "onLoaded", data: nil)
            self.sendEvent(name: "onMessage", data: [
                "target": "Unreal",
                "method": "onReady",
                "data": "{\"success\":true,\"message\":\"Unreal Engine ready\"}"
            ])
        }
    }

    /// Called from the bridge once the engine's view exists.
    @objc public func onUnrealViewReady(_ view: NSView) {
        DispatchQueue.main.async { [weak self] in
            self?.attach(view)
        }
    }

    private func attach(_ view: NSView) {
        NSLog("UnrealEngineController: Unreal render view arrived")
        unrealView = view
        addEngineView(view)
        engineViewDidResize(to: self.view().bounds.size)
        sendEvent(name: "onAttached", data: nil)
    }

    public override func attachEngine() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let view = self.unrealView else { return }
            self.addEngineView(view)
        }
    }

    public override func detachEngine() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.removeEngineView()
            self.sendEvent(name: "onDetached", data: nil)
        }
    }

    /// Push the current container size down to the engine.
    ///
    /// Points, not pixels. AppKit scales for the backing store itself, and
    /// multiplying by the scale factor again would render four times the area
    /// on any Retina display.
    public override func engineViewDidResize(to size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        UnrealBridge.shared.resizeView(to: size)
    }

    public override func pauseEngine() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            UnrealBridge.shared.pause()
            self._isPaused = true
            self.sendEvent(name: "onPaused", data: nil)
        }
    }

    public override func resumeEngine() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            UnrealBridge.shared.resume()
            self._isPaused = false
            self.sendEvent(name: "onResumed", data: nil)
        }
    }

    /// Give back everything an idle engine is holding, short of tearing it down.
    ///
    /// Unreal cannot be unloaded and started again in one process, so this is
    /// not a teardown. The game pauses and the render view goes away, which is
    /// the expensive part. Reversible through reloadEngine.
    public override func unloadEngine() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            NSLog("UnrealEngineController: Unloading Unreal (pausing, releasing the view)")
            UnrealBridge.shared.pause()
            UnrealBridge.shared.destroyView()

            self.removeEngineView()
            self.unrealView = nil
            self._isPaused = true
            self.isUnloaded = true

            self.sendEvent(name: "onUnloaded", data: nil)
        }
    }

    public override func reloadEngine() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.isUnloaded else { return }

            NSLog("UnrealEngineController: Reloading Unreal")
            self.isUnloaded = false
            UnrealBridge.shared.restoreView()
            UnrealBridge.shared.resume()

            self._isPaused = false
            self.sendEvent(name: "onLoaded", data: nil)
        }
    }

    public override func destroyEngine() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            UnrealBridge.shared.quit()
            self.removeEngineView()
            self.unrealView = nil
            self._isReady = false
            self.sendEvent(name: "onDestroyed", data: nil)
        }
    }

    public override func sendMessage(target: String, method: String, data: String) {
        DispatchQueue.main.async {
            NSLog("UnrealEngineController: Sending message - Target: \(target), Method: \(method)")
            UnrealBridge.shared.sendMessage(target: target, method: method, data: data)
        }
    }

    // MARK: - Called from the bridge

    @objc public func onMessageFromUnreal(target: String, method: String, data: String) {
        sendEvent(name: "onMessage", data: [
            "target": target,
            "method": method,
            "data": data
        ])
    }

    @objc public func onLevelLoaded(levelName: String, buildIndex: Int) {
        sendEvent(name: "onSceneLoaded", data: [
            "name": levelName,
            "buildIndex": buildIndex,
            "isLoaded": true
        ])
    }
}

/// Builds controllers for the shared registry.
public class UnrealEngineFactory: NSObject, GameEngineFactory {
    public func createController(
        frame: CGRect,
        viewId: Int64,
        messenger: FlutterBinaryMessenger,
        config: [String: Any]
    ) -> GameEnginePlatformView {
        NSLog("UnrealEngineFactory: Creating controller with viewId \(viewId)")
        return UnrealEngineController(
            frame: frame,
            viewId: viewId,
            messenger: messenger,
            config: config
        )
    }
}
