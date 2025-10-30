import UIKit
import UnityFramework

class UnityPlayerManager {
    static let shared = UnityPlayerManager()

    private var unityFramework: UnityFramework?
    private var isUnityLoaded = false

    private init() {}

    func isInitialized() -> Bool {
        return isUnityLoaded && unityFramework != nil
    }

    func getUnityVersion() -> String {
        return unityFramework?.appVersion() ?? "Unknown"
    }

    func getUnityView() throws -> UIView? {
        if unityFramework == nil {
            try loadUnityFramework()
        }

        return unityFramework?.appController()?.rootView
    }

    func sendMessage(gameObject: String, methodName: String, message: String) {
        unityFramework?.sendMessageToGO(
            withName: gameObject,
            functionName: methodName,
            message: message
        )
    }

    func pause() {
        unityFramework?.pause(true)
    }

    func resume() {
        unityFramework?.pause(false)
    }

    func unload() {
        unityFramework?.unloadApplication()
        unityFramework = nil
        isUnityLoaded = false
    }

    private func loadUnityFramework() throws {
        guard let bundlePath = Bundle.main.path(forResource: "UnityFramework", ofType: "framework", inDirectory: "Frameworks") else {
            throw UnityError.frameworkNotFound
        }

        guard let bundle = Bundle(path: bundlePath) else {
            throw UnityError.bundleLoadFailed
        }

        if !bundle.isLoaded {
            bundle.load()
        }

        guard let ufw = bundle.principalClass?.getInstance() else {
            throw UnityError.instanceCreationFailed
        }

        if let framework = ufw as? UnityFramework {
            unityFramework = framework
            unityFramework?.setDataBundleId(Bundle.main.bundleIdentifier ?? "")
            unityFramework?.runEmbedded(
                withArgc: CommandLine.argc,
                argv: CommandLine.unsafeArgv,
                appLaunchOpts: nil
            )
            isUnityLoaded = true
        } else {
            throw UnityError.castFailed
        }
    }
}

enum UnityError: Error {
    case frameworkNotFound
    case bundleLoadFailed
    case instanceCreationFailed
    case castFailed
}
