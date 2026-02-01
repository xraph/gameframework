#ifndef FLUTTER_PLUGIN_GAMEFRAMEWORK_PLUGIN_H_
#define FLUTTER_PLUGIN_GAMEFRAMEWORK_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>

namespace gameframework {

class GameframeworkPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  GameframeworkPlugin();

  virtual ~GameframeworkPlugin();

  // Disallow copy and assign.
  GameframeworkPlugin(const GameframeworkPlugin&) = delete;
  GameframeworkPlugin& operator=(const GameframeworkPlugin&) = delete;

  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

}  // namespace gameframework

#endif  // FLUTTER_PLUGIN_GAMEFRAMEWORK_PLUGIN_H_
