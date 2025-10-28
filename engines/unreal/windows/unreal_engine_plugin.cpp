#include "unreal_engine_plugin.h"

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <sstream>
#include <windows.h>

namespace gameframework_unreal {

// Static
void UnrealEnginePlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows *registrar) {
  auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "gameframework_unreal",
          &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<UnrealEnginePlugin>();

  channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto &call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  registrar->AddPlugin(std::move(plugin));
}

UnrealEnginePlugin::UnrealEnginePlugin() {}

UnrealEnginePlugin::~UnrealEnginePlugin() {}

void UnrealEnginePlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue> &method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {

  const std::string& method = method_call.method_name();

  if (method.compare("getPlatformVersion") == 0) {
    // Get Windows version
    OSVERSIONINFOEX osvi;
    ZeroMemory(&osvi, sizeof(OSVERSIONINFOEX));
    osvi.dwOSVersionInfoSize = sizeof(OSVERSIONINFOEX);

    std::ostringstream version_stream;
    version_stream << "Windows " << osvi.dwMajorVersion << "." << osvi.dwMinorVersion;
    result->Success(flutter::EncodableValue(version_stream.str()));
  }
  else if (method.compare("getEngineType") == 0) {
    result->Success(flutter::EncodableValue("unreal"));
  }
  else if (method.compare("getEngineVersion") == 0) {
    result->Success(flutter::EncodableValue("5.3.0"));
  }
  else if (method.compare("isEngineSupported") == 0) {
    result->Success(flutter::EncodableValue(true));
  }
  else if (method.compare("engine#create") == 0) {
    // TODO: Implement Unreal Engine initialization
    // This will require loading UnrealEngine.dll and creating the engine instance
    result->Success(flutter::EncodableValue(false));
  }
  else if (method.compare("engine#pause") == 0) {
    // TODO: Implement pause
    result->Success();
  }
  else if (method.compare("engine#resume") == 0) {
    // TODO: Implement resume
    result->Success();
  }
  else if (method.compare("engine#unload") == 0) {
    // TODO: Implement unload
    result->Success();
  }
  else if (method.compare("engine#quit") == 0) {
    // TODO: Implement quit
    result->Success();
  }
  else if (method.compare("engine#sendMessage") == 0) {
    // TODO: Implement message sending to Unreal
    result->Success();
  }
  else if (method.compare("engine#sendJsonMessage") == 0) {
    // TODO: Implement JSON message sending to Unreal
    result->Success();
  }
  else if (method.compare("engine#executeConsoleCommand") == 0) {
    // TODO: Implement console command execution
    result->Success();
  }
  else if (method.compare("engine#loadLevel") == 0) {
    // TODO: Implement level loading
    result->Success();
  }
  else if (method.compare("engine#applyQualitySettings") == 0) {
    // TODO: Implement quality settings
    result->Success();
  }
  else if (method.compare("engine#getQualitySettings") == 0) {
    // TODO: Implement get quality settings
    auto settings = flutter::EncodableMap();
    result->Success(flutter::EncodableValue(settings));
  }
  else if (method.compare("engine#isInBackground") == 0) {
    result->Success(flutter::EncodableValue(false));
  }
  else {
    result->NotImplemented();
  }
}

}  // namespace gameframework_unreal
