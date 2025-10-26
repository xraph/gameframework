#include "include/gameframework/gameframework_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "gameframework_plugin.h"

void GameframeworkPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  gameframework::GameframeworkPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
