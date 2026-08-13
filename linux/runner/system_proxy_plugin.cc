#include "system_proxy_plugin.h"

#include <gio/gio.h>
#include <cstring>

namespace {

constexpr char kChannelName[] = "com.riotwwks.riogram/system_proxy";

FlMethodChannel* g_channel = nullptr;

bool ParseProxyUri(const char* uri, gchar** host, guint* port, gchar** type) {
  if (uri == nullptr || host == nullptr || port == nullptr || type == nullptr) {
    return false;
  }

  gchar* scheme = nullptr;
  gchar* userinfo = nullptr;
  gchar* hostname = nullptr;
  gchar* port_str = nullptr;
  gchar* path = nullptr;
  GError* error = nullptr;

  if (!g_uri_split_network(uri, G_URI_FLAGS_NONE, &scheme, &userinfo, &hostname,
                         &port_str, &path, &error)) {
    g_clear_error(&error);
    return false;
  }

  *host = hostname;
  if (port_str != nullptr && port_str[0] != '\0') {
    *port = static_cast<guint>(g_ascii_strtoll(port_str, nullptr, 10));
  } else if (scheme != nullptr &&
             (g_strcmp0(scheme, "socks5") == 0 || g_strcmp0(scheme, "socks") == 0 ||
              g_strcmp0(scheme, "socks4") == 0)) {
    *port = 1080;
  } else {
    *port = 8080;
  }

  if (scheme != nullptr &&
      (g_strcmp0(scheme, "socks5") == 0 || g_strcmp0(scheme, "socks") == 0 ||
       g_strcmp0(scheme, "socks4") == 0)) {
    *type = g_strdup("socks5");
  } else {
    *type = g_strdup("http");
  }

  g_free(scheme);
  g_free(userinfo);
  g_free(port_str);
  g_free(path);
  return *host != nullptr && (*host)[0] != '\0' && *port > 0;
}

FlValue* BuildProxyMap(const gchar* host, guint port, const gchar* type,
                       const gchar* username, const gchar* password) {
  g_autoptr(FlValue) result = fl_value_new_map();
  fl_value_set_string_take(result, "host", fl_value_new_string(host));
  fl_value_set_string_take(result, "port", fl_value_new_int(static_cast<int64_t>(port)));
  fl_value_set_string_take(result, "type", fl_value_new_string(type));
  fl_value_set_string_take(result, "username",
                           fl_value_new_string(username != nullptr ? username : ""));
  fl_value_set_string_take(result, "password",
                           fl_value_new_string(password != nullptr ? password : ""));
  return fl_value_ref(result);
}

FlValue* LookupSystemProxy() {
  g_autoptr(GError) error = nullptr;
  g_autoptr(GProxyResolver) resolver = g_proxy_resolver_get_default();
  if (resolver == nullptr) {
    return nullptr;
  }

  gchar** proxies =
      g_proxy_resolver_lookup_sync(resolver, "https://telegram.org", nullptr, nullptr, &error);
  if (proxies == nullptr) {
    return nullptr;
  }

  FlValue* result = nullptr;
  for (gchar** iter = proxies; *iter != nullptr; iter++) {
    if (g_strcmp0(*iter, "direct://") == 0) {
      continue;
    }

    gchar* host = nullptr;
    guint port = 0;
    gchar* type = nullptr;
    if (!ParseProxyUri(*iter, &host, &port, &type)) {
      continue;
    }

    gchar* username = nullptr;
    gchar* password = nullptr;
    g_autoptr(GUri) uri = g_uri_parse(*iter, G_URI_FLAGS_NONE, &error);
    g_clear_error(&error);
    if (uri != nullptr) {
      const gchar* userinfo = g_uri_get_userinfo(uri);
      if (userinfo != nullptr && userinfo[0] != '\0') {
        gchar** parts = g_strsplit(userinfo, ":", 2);
        if (parts != nullptr) {
          if (parts[0] != nullptr) {
            username = g_uri_unescape_string(parts[0], nullptr);
          }
          if (parts[1] != nullptr) {
            password = g_uri_unescape_string(parts[1], nullptr);
          }
          g_strfreev(parts);
        }
      }
    }

    result = BuildProxyMap(host, port, type, username, password);
    g_free(host);
    g_free(type);
    g_free(username);
    g_free(password);
    break;
  }

  g_strfreev(proxies);
  return result;
}

void MethodCallHandler(FlMethodChannel* channel, FlMethodCall* method_call, gpointer user_data) {
  const gchar* method = fl_method_call_get_name(method_call);
  if (g_strcmp0(method, "getSystemProxy") != 0) {
    fl_method_call_respond_not_implemented(method_call, nullptr);
    return;
  }

  g_autoptr(FlValue) proxy = LookupSystemProxy();
  if (proxy != nullptr) {
    fl_method_call_respond_success(method_call, proxy, nullptr);
    return;
  }
  fl_method_call_respond_success(method_call, fl_value_new_null(), nullptr);
}

}  // namespace

void system_proxy_plugin_register(FlEngine* engine) {
  if (engine == nullptr || g_channel != nullptr) {
    return;
  }

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  g_channel = fl_method_channel_new(fl_engine_get_binary_messenger(engine), kChannelName,
                                    FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(g_channel, MethodCallHandler, nullptr, nullptr);
}
