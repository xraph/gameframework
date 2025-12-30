#include "include/gameframework_unity/unity_engine_plugin.h"

// This must be included before many other Windows headers.
#include <windows.h>

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <sstream>

namespace gameframework_unity {

// Static
void UnityEnginePlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows *registrar) {
  auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "gameframework_unity",
          &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<UnityEnginePlugin>();

  channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto &call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  registrar->AddPlugin(std::move(plugin));
}

UnityEnginePlugin::UnityEnginePlugin() {}

UnityEnginePlugin::~UnityEnginePlugin() {}

void UnityEnginePlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue> &method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {

  if (method_call.method_name().compare("getPlatformVersion") == 0) {
    std::ostringstream version_stream;
    version_stream << "Windows ";

    // Get Windows version
    OSVERSIONINFOEX osvi;
    ZeroMemory(&osvi, sizeof(OSVERSIONINFOEX));
    osvi.dwOSVersionInfoSize = sizeof(OSVERSIONINFOEX);

    #pragma warning(push)
    #pragma warning(disable: 4996) // Disable deprecation warning
    GetVersionEx((OSVERSIONINFO*)&osvi);
    #pragma warning(pop)

    version_stream << osvi.dwMajorVersion << "." << osvi.dwMinorVersion;

    result->Success(flutter::EncodableValue(version_stream.str()));
  }
  else if (method_call.method_name().compare("getEngineType") == 0) {
    result->Success(flutter::EncodableValue("unity"));
  }
  else if (method_call.method_name().compare("getEngineVersion") == 0) {
    result->Success(flutter::EncodableValue("2022.3.0"));
  }
  else if (method_call.method_name().compare("isEngineSupported") == 0) {
    result->Success(flutter::EncodableValue(true));
  }
  else {
    result->NotImplemented();
  }
}

}  // namespace gameframework_unity
