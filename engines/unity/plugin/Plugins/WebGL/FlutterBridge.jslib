/**
 * WebGL JavaScript plugin for Unity-Flutter communication
 *
 * This plugin provides native JavaScript methods that Unity C# scripts can call
 * via [DllImport("__Internal")] to communicate with the Flutter web host.
 *
 * Communication flow:
 *   Unity C# -> [DllImport] -> FlutterBridge.jslib -> window.FlutterUnityReceiveMessage -> Flutter Dart
 *
 * The Flutter Dart web controller registers global window functions that this
 * plugin calls when Unity sends messages.
 */
var FlutterBridgeWebGLPlugin = {

    /**
     * Send a structured message from Unity to Flutter.
     * Called by FlutterBridge.cs SendToFlutter().
     *
     * @param {number} targetPtr - Pointer to UTF8 target string
     * @param {number} methodPtr - Pointer to UTF8 method string
     * @param {number} dataPtr   - Pointer to UTF8 data string
     */
    SendMessageToFlutter: function(targetPtr, methodPtr, dataPtr) {
        var target = UTF8ToString(targetPtr);
        var method = UTF8ToString(methodPtr);
        var data = UTF8ToString(dataPtr);

        if (typeof window.FlutterUnityReceiveMessage === 'function') {
            try {
                window.FlutterUnityReceiveMessage(target, method, data);
            } catch (e) {
                console.error('[FlutterBridge WebGL] Error calling FlutterUnityReceiveMessage:', e);
            }
        } else {
            console.warn('[FlutterBridge WebGL] FlutterUnityReceiveMessage not registered. Message dropped:', target, method);
        }
    },

    /**
     * Send a simple (unstructured) message from Unity to Flutter.
     * Called by NativeAPI.cs _sendMessageToFlutter().
     *
     * @param {number} messagePtr - Pointer to UTF8 message string
     */
    _sendMessageToFlutter: function(messagePtr) {
        var message = UTF8ToString(messagePtr);

        if (typeof window.FlutterUnityReceiveMessage === 'function') {
            try {
                window.FlutterUnityReceiveMessage('Unity', 'onMessage', message);
            } catch (e) {
                console.error('[FlutterBridge WebGL] Error calling FlutterUnityReceiveMessage:', e);
            }
        } else {
            console.warn('[FlutterBridge WebGL] FlutterUnityReceiveMessage not registered. Simple message dropped.');
        }
    },

    /**
     * Notify Flutter that a Unity scene has been loaded.
     * Called by FlutterBridge.cs NotifySceneLoaded().
     *
     * @param {number} namePtr    - Pointer to UTF8 scene name string
     * @param {number} buildIndex - Integer build index of the loaded scene
     */
    SendSceneLoadedToFlutter: function(namePtr, buildIndex) {
        var name = UTF8ToString(namePtr);

        if (typeof window.FlutterUnitySceneLoaded === 'function') {
            try {
                window.FlutterUnitySceneLoaded(name, buildIndex);
            } catch (e) {
                console.error('[FlutterBridge WebGL] Error calling FlutterUnitySceneLoaded:', e);
            }
        } else {
            console.warn('[FlutterBridge WebGL] FlutterUnitySceneLoaded not registered. Scene event dropped:', name);
        }
    },

    /**
     * Notify Flutter that Unity is ready.
     * Called by NativeAPI.cs _notifyUnityReady().
     */
    _notifyUnityReady: function() {
        if (typeof window.FlutterUnityReceiveMessage === 'function') {
            try {
                window.FlutterUnityReceiveMessage('Unity', 'onReady', 'true');
            } catch (e) {
                console.error('[FlutterBridge WebGL] Error notifying Unity ready:', e);
            }
        } else {
            console.warn('[FlutterBridge WebGL] FlutterUnityReceiveMessage not registered. Ready notification dropped.');
        }
    },

    /**
     * Show the Flutter host window (no-op on WebGL since browser is the host).
     */
    _showHostMainWindow: function() {
        // No-op on WebGL - the browser window is always visible
        console.log('[FlutterBridge WebGL] _showHostMainWindow called (no-op on WebGL)');
    },

    /**
     * Unload Unity WebGL instance.
     * The actual unload is handled by the Flutter Dart controller via unityInstance.Quit().
     */
    _unloadUnity: function() {
        if (typeof window.FlutterUnityReceiveMessage === 'function') {
            try {
                window.FlutterUnityReceiveMessage('Unity', 'onUnloadRequest', '');
            } catch (e) {
                console.error('[FlutterBridge WebGL] Error requesting unload:', e);
            }
        }
    },

    /**
     * Quit Unity WebGL instance.
     * The actual quit is handled by the Flutter Dart controller via unityInstance.Quit().
     */
    _quitUnity: function() {
        if (typeof window.FlutterUnityReceiveMessage === 'function') {
            try {
                window.FlutterUnityReceiveMessage('Unity', 'onQuitRequest', '');
            } catch (e) {
                console.error('[FlutterBridge WebGL] Error requesting quit:', e);
            }
        }
    }
};

mergeInto(LibraryManager.library, FlutterBridgeWebGLPlugin);
