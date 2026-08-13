#include "system_proxy_plugin.h"

#include <gio/gio.h>

#include <cstring>

namespace {

constexpr char kChannelName[] = "com.riotwwks.riogram/system_proxy";

FlMethodChannel* g_channel = nullptr;

bool IsSocksScheme(const char* scheme) {
  return scheme != nullptr &&
         (g_strcmp0(scheme, "socks5") == 0 || g_strcmp0(scheme, "socks") == 0 ||
          g_strcmp0(scheme, "socks4") == 0);
}

guint DefaultPortForScheme(const char* scheme) {
  return IsSocksScheme(scheme) ? 1080 : 8080;
}

bool ParseProxyUri(const char* uri, gchar** host, guint* port, gchar** type) {
  if (uri == nullptr || host == nullptr || port == nullptr || type == nullptr) {
    return false;
  }

  g_autofree gchar* scheme = nullptr;
  g_autofree gchar* authority = nullptr;

  const char* rest = uri;
  const char* scheme_end = strstr(uri, "://");
  if (scheme_end != nullptr) {
    scheme = g_strndup(uri, static_cast<gsize>(scheme_end - uri));
    rest = scheme_end + 3;
  } else {
    scheme = g_strdup("http");
  }

  const char* slash = strchr(rest, '/');
  if (slash != nullptr) {
    authority = g_strndup(rest, static_cast<gsize>(slash - rest));
  } else {
    authority = g_strdup(rest);
  }

  const char* at = strrchr(authority, '@');
  const char* host_port = at != nullptr ? at + 1 : authority;

  const char* colon = strrchr(host_port, ':');
  if (colon != nullptr && colon > host_port) {
    *host = g_strndup(host_port, static_cast<gsize>(colon - host_port));
    *port = static_cast<guint>(g_ascii_strtoull(colon + 1, nullptr, 10));
  } else {
    *host = g_strdup(host_port);
    *port = DefaultPortForScheme(scheme);
  }

  if (*port == 0) {
    *port = DefaultPortForScheme(scheme);
  }

  *type = g_strdup(IsSocksScheme(scheme) ? "socks5" : "http");
  return *host != nullptr && (*host)[0] != '\0' && *port > 0;
}

FlValue* BuildProxyMap(const gchar* host, guint port, const gchar* type) {
  g_autoptr(FlValue) result = fl_value_new_map();
  fl_value_set_string_take(result, "host", fl_value_new_string(host));
  fl_value_set_string_take(result, "port", fl_value_new_int(static_cast<int64_t>(port)));
  fl_value_set_string_take(result, "type", fl_value_new_string(type));
  fl_value_set_string_take(result, "username", fl_value_new_string(""));
  fl_value_set_string_take(result, "password", fl_value_new_string(""));
  return fl_value_ref(result);
}

FlValue* LookupSystemProxy() {
  g_autoptr(GError) error = nullptr;
  g_autoptr(GProxyResolver) resolver = g_proxy_resolver_get_default();
  if (resolver == nullptr) {
    return nullptr;
  }

  gchar** proxies =
      g_proxy_resolver_lookup(resolver, "https://telegram.org", nullptr, &error);
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

    result = BuildProxyMap(host, port, type);
    g_free(host);
    g_free(type);
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
