import Flutter
import UIKit

/**
 * Unreal Engine Plugin for iOS
 *
 * Manages Unreal Engine integration with Flutter on iOS.
 * Provides lifecycle management, communication, and quality settings control.
 */
public class UnrealEnginePlugin: NSObject, FlutterPlugin {

    // MARK: - Properties

    private var channel: FlutterMethodChannel?
    private var controllers: [Int: UnrealEngineController] = [:]

    // MARK: - Constants

    private static let channelName = "gameframework_unreal"
    private static let engineType = "unreal"
    private static let engineVersion = "5.3.0"

    // MARK: - Plugin Registration

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: channelName,
            binaryMessenger: registrar.messenger()
        )

        let instance = UnrealEnginePlugin()
        instance.channel = channel

        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    // MARK: - Method Call Handler

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getPlatformVersion":
            handleGetPlatformVersion(result: result)

        case "getEngineType":
            handleGetEngineType(result: result)

        case "getEngineVersion":
            handleGetEngineVersion(result: result)

        case "isEngineSupported":
            handleIsEngineSupported(result: result)

        case "engine#create":
            handleEngineCreate(call: call, result: result)

        case "engine#pause":
            handleEnginePause(call: call, result: result)

        case "engine#resume":
            handleEngineResume(call: call, result: result)

        case "engine#unload":
            handleEngineUnload(call: call, result: result)

        case "engine#quit":
            handleEngineQuit(call: call, result: result)

        case "engine#sendMessage":
            handleSendMessage(call: call, result: result)

        case "engine#sendJsonMessage":
            handleSendJsonMessage(call: call, result: result)

        case "engine#executeConsoleCommand":
            handleExecuteConsoleCommand(call: call, result: result)

        case "engine#loadLevel":
            handleLoadLevel(call: call, result: result)

        case "engine#applyQualitySettings":
            handleApplyQualitySettings(call: call, result: result)

        case "engine#getQualitySettings":
            handleGetQualitySettings(call: call, result: result)

        case "engine#isInBackground":
            handleIsInBackground(call: call, result: result)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Platform Info Handlers

    private func handleGetPlatformVersion(result: @escaping FlutterResult) {
        let version = UIDevice.current.systemVersion
        result("iOS \(version)")
    }

    private func handleGetEngineType(result: @escaping FlutterResult) {
        result(UnrealEnginePlugin.engineType)
    }

    private func handleGetEngineVersion(result: @escaping FlutterResult) {
        result(UnrealEnginePlugin.engineVersion)
    }

    private func handleIsEngineSupported(result: @escaping FlutterResult) {
        result(true)
    }

    // MARK: - Engine Lifecycle Handlers

    private func handleEngineCreate(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let viewId = args["viewId"] as? Int else {
            result(FlutterError(
                code: "INVALID_ARGUMENTS",
                message: "viewId is required",
                details: nil
            ))
            return
        }

        let config = args["config"] as? [String: Any] ?? [:]

        guard let channel = self.channel else {
            result(FlutterError(
                code: "NO_CHANNEL",
                message: "Method channel not available",
                details: nil
            ))
            return
        }

        let controller = UnrealEngineController(
            viewId: viewId,
            channel: channel,
            config: config
        )

        let success = controller.create()
        if success {
            controllers[viewId] = controller
        }

        result(success)
    }

    private func handleEnginePause(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let controller = getController(from: call) else {
            result(FlutterError(
                code: "NO_CONTROLLER",
                message: "Controller not found",
                details: nil
            ))
            return
        }

        controller.pause()
        result(nil)
    }

    private func handleEngineResume(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let controller = getController(from: call) else {
            result(FlutterError(
                code: "NO_CONTROLLER",
                message: "Controller not found",
                details: nil
            ))
            return
        }

        controller.resume()
        result(nil)
    }

    private func handleEngineUnload(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let controller = getController(from: call) else {
            result(FlutterError(
                code: "NO_CONTROLLER",
                message: "Controller not found",
                details: nil
            ))
            return
        }

        controller.unload()
        result(nil)
    }

    private func handleEngineQuit(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let viewId = args["viewId"] as? Int else {
            result(FlutterError(
                code: "INVALID_ARGUMENTS",
                message: "viewId is required",
                details: nil
            ))
            return
        }

        if let controller = controllers[viewId] {
            controller.quit()
            controllers.removeValue(forKey: viewId)
        }

        result(nil)
    }

    // MARK: - Communication Handlers

    private func handleSendMessage(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let controller = getController(from: call),
              let args = call.arguments as? [String: Any],
              let target = args["target"] as? String,
              let method = args["method"] as? String,
              let data = args["data"] as? String else {
            result(FlutterError(
                code: "INVALID_ARGUMENTS",
                message: "target, method, and data are required",
                details: nil
            ))
            return
        }

        controller.sendMessage(target: target, method: method, data: data)
        result(nil)
    }

    private func handleSendJsonMessage(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let controller = getController(from: call),
              let args = call.arguments as? [String: Any],
              let target = args["target"] as? String,
              let method = args["method"] as? String,
              let data = args["data"] as? [String: Any] else {
            result(FlutterError(
                code: "INVALID_ARGUMENTS",
                message: "target, method, and data are required",
                details: nil
            ))
            return
        }

        controller.sendJsonMessage(target: target, method: method, data: data)
        result(nil)
    }

    // MARK: - Unreal-Specific Handlers

    private func handleExecuteConsoleCommand(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let controller = getController(from: call),
              let args = call.arguments as? [String: Any],
              let command = args["command"] as? String else {
            result(FlutterError(
                code: "INVALID_ARGUMENTS",
                message: "command is required",
                details: nil
            ))
            return
        }

        controller.executeConsoleCommand(command)
        result(nil)
    }

    private func handleLoadLevel(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let controller = getController(from: call),
              let args = call.arguments as? [String: Any],
              let levelName = args["levelName"] as? String else {
            result(FlutterError(
                code: "INVALID_ARGUMENTS",
                message: "levelName is required",
                details: nil
            ))
            return
        }

        controller.loadLevel(levelName)
        result(nil)
    }

    private func handleApplyQualitySettings(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let controller = getController(from: call),
              let settings = call.arguments as? [String: Any] else {
            result(FlutterError(
                code: "INVALID_ARGUMENTS",
                message: "settings are required",
                details: nil
            ))
            return
        }

        controller.applyQualitySettings(settings)
        result(nil)
    }

    private func handleGetQualitySettings(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let controller = getController(from: call) else {
            result(FlutterError(
                code: "NO_CONTROLLER",
                message: "Controller not found",
                details: nil
            ))
            return
        }

        if let settings = controller.getQualitySettings() {
            result(settings)
        } else {
            result(FlutterError(
                code: "SETTINGS_ERROR",
                message: "Failed to get quality settings",
                details: nil
            ))
        }
    }

    private func handleIsInBackground(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let controller = getController(from: call) else {
            result(FlutterError(
                code: "NO_CONTROLLER",
                message: "Controller not found",
                details: nil
            ))
            return
        }

        let isBackground = controller.isInBackground()
        result(isBackground)
    }

    // MARK: - Helper Methods

    private func getController(from call: FlutterMethodCall) -> UnrealEngineController? {
        guard let args = call.arguments as? [String: Any],
              let viewId = args["viewId"] as? Int else {
            return nil
        }

        return controllers[viewId]
    }

    // MARK: - Cleanup

    deinit {
        // Clean up all controllers
        for (_, controller) in controllers {
            controller.quit()
        }
        controllers.removeAll()
    }
}
