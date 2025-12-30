#ifndef FLUTTER_PLUGIN_UNITY_ENGINE_PLUGIN_H_
#define FLUTTER_PLUGIN_UNITY_ENGINE_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>

namespace gameframework_unity {

class UnityEnginePlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  UnityEnginePlugin();

  virtual ~UnityEnginePlugin();

  // Disallow copy and assign.
  UnityEnginePlugin(const UnityEnginePlugin&) = delete;
  UnityEnginePlugin& operator=(const UnityEnginePlugin&) = delete;

 private:
  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

}  // namespace gameframework_unity

#endif  // FLUTTER_PLUGIN_UNITY_ENGINE_PLUGIN_H_
