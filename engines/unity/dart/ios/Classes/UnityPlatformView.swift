import Flutter
import UIKit

class UnityPlatformView: NSObject, FlutterPlatformView {
    private var _view: UIView
    private var methodChannel: FlutterMethodChannel
    private var unityView: UIView?

    init(
        frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?,
        binaryMessenger messenger: FlutterBinaryMessenger
    ) {
        _view = UIView(frame: frame)
        methodChannel = FlutterMethodChannel(
            name: "com.xraph.gameframework.unity/view_\(viewId)",
            binaryMessenger: messenger
        )
        super.init()

        methodChannel.setMethodCallHandler(handleMethodCall)
        initializeUnityView(args: args)
    }

    func view() -> UIView {
        return _view
    }

    private func initializeUnityView(args: Any?) {
        do {
            unityView = try UnityPlayerManager.shared.getUnityView()

            if let unityView = unityView {
                unityView.frame = _view.bounds
                unityView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                _view.addSubview(unityView)

                // Notify Flutter that Unity is ready
                methodChannel.invokeMethod("onUnityReady", arguments: nil)
            } else {
                showErrorView(message: "Unity not initialized. Make sure UnityFramework is properly integrated.")
            }
        } catch {
            showErrorView(message: "Error initializing Unity: \(error.localizedDescription)")
        }
    }

    private func showErrorView(message: String) {
        let label = UILabel(frame: _view.bounds)
        label.text = message
        label.textAlignment = .center
        label.numberOfLines = 0
        label.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        _view.addSubview(label)
    }

    private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "pause":
            UnityPlayerManager.shared.pause()
            result(nil)

        case "resume":
            UnityPlayerManager.shared.resume()
            result(nil)

        case "sendMessage":
            guard let args = call.arguments as? [String: Any],
                  let gameObject = args["gameObject"] as? String,
                  let methodName = args["methodName"] as? String else {
                result(FlutterError(
                    code: "INVALID_ARGS",
                    message: "Missing arguments",
                    details: nil
                ))
                return
            }

            let message = args["message"] as? String ?? ""
            UnityPlayerManager.shared.sendMessage(
                gameObject: gameObject,
                methodName: methodName,
                message: message
            )
            result(nil)

        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
