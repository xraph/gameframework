//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <gameframework/gameframework_plugin_c_api.h>
#include <gameframework_unity/unity_engine_plugin.h>

void RegisterPlugins(flutter::PluginRegistry* registry) {
  GameframeworkPluginCApiRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("GameframeworkPluginCApi"));
  UnityEnginePluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("UnityEnginePlugin"));
}
