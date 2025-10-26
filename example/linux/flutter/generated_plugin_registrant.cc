//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <gameframework/gameframework_plugin.h>

void fl_register_plugins(FlPluginRegistry* registry) {
  g_autoptr(FlPluginRegistrar) gameframework_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "GameframeworkPlugin");
  gameframework_plugin_register_with_registrar(gameframework_registrar);
}
