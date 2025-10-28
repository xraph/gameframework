#include "include/gameframework_unreal/unreal_engine_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>
#include <sys/utsname.h>

#include <cstring>

#define UNREAL_ENGINE_PLUGIN(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), unreal_engine_plugin_get_type(), \
                               UnrealEnginePlugin))

struct _UnrealEnginePlugin {
  GObject parent_instance;
};

G_DEFINE_TYPE(UnrealEnginePlugin, unreal_engine_plugin, g_object_get_type())

// Called when a method call is received from Flutter.
static void unreal_engine_plugin_handle_method_call(
    UnrealEnginePlugin* self,
    FlMethodCall* method_call) {
  g_autoptr(FlMethodResponse) response = nullptr;

  const gchar* method = fl_method_call_get_name(method_call);

  if (strcmp(method, "getPlatformVersion") == 0) {
    struct utsname uname_data = {};
    uname(&uname_data);
    g_autofree gchar *version = g_strdup_printf("Linux %s", uname_data.version);
    g_autoptr(FlValue) result = fl_value_new_string(version);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  }
  else if (strcmp(method, "getEngineType") == 0) {
    g_autoptr(FlValue) result = fl_value_new_string("unreal");
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  }
  else if (strcmp(method, "getEngineVersion") == 0) {
    g_autoptr(FlValue) result = fl_value_new_string("5.3.0");
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  }
  else if (strcmp(method, "isEngineSupported") == 0) {
    g_autoptr(FlValue) result = fl_value_new_bool(TRUE);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  }
  else if (strcmp(method, "engine#create") == 0) {
    // TODO: Implement Unreal Engine initialization
    g_autoptr(FlValue) result = fl_value_new_bool(FALSE);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  }
  else if (strcmp(method, "engine#pause") == 0) {
    // TODO: Implement pause
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  }
  else if (strcmp(method, "engine#resume") == 0) {
    // TODO: Implement resume
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  }
  else if (strcmp(method, "engine#unload") == 0) {
    // TODO: Implement unload
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  }
  else if (strcmp(method, "engine#quit") == 0) {
    // TODO: Implement quit
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  }
  else if (strcmp(method, "engine#sendMessage") == 0) {
    // TODO: Implement message sending to Unreal
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  }
  else if (strcmp(method, "engine#sendJsonMessage") == 0) {
    // TODO: Implement JSON message sending to Unreal
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  }
  else if (strcmp(method, "engine#executeConsoleCommand") == 0) {
    // TODO: Implement console command execution
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  }
  else if (strcmp(method, "engine#loadLevel") == 0) {
    // TODO: Implement level loading
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  }
  else if (strcmp(method, "engine#applyQualitySettings") == 0) {
    // TODO: Implement quality settings
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  }
  else if (strcmp(method, "engine#getQualitySettings") == 0) {
    // TODO: Implement get quality settings
    g_autoptr(FlValue) result = fl_value_new_map();
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  }
  else if (strcmp(method, "engine#isInBackground") == 0) {
    g_autoptr(FlValue) result = fl_value_new_bool(FALSE);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  }
  else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  fl_method_call_respond(method_call, response, nullptr);
}

static void unreal_engine_plugin_dispose(GObject* object) {
  G_OBJECT_CLASS(unreal_engine_plugin_parent_class)->dispose(object);
}

static void unreal_engine_plugin_class_init(UnrealEnginePluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = unreal_engine_plugin_dispose;
}

static void unreal_engine_plugin_init(UnrealEnginePlugin* self) {}

static void method_call_cb(FlMethodChannel* channel, FlMethodCall* method_call,
                            gpointer user_data) {
  UnrealEnginePlugin* plugin = UNREAL_ENGINE_PLUGIN(user_data);
  unreal_engine_plugin_handle_method_call(plugin, method_call);
}

void unreal_engine_plugin_register_with_registrar(FlPluginRegistrar* registrar) {
  UnrealEnginePlugin* plugin = UNREAL_ENGINE_PLUGIN(
      g_object_new(unreal_engine_plugin_get_type(), nullptr));

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  g_autoptr(FlMethodChannel) channel =
      fl_method_channel_new(fl_plugin_registrar_get_messenger(registrar),
                            "gameframework_unreal",
                            FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(channel, method_call_cb,
                                             g_object_ref(plugin),
                                             g_object_unref);

  g_object_unref(plugin);
}
