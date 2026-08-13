#ifndef RUNNER_SYSTEM_PROXY_PLUGIN_H_
#define RUNNER_SYSTEM_PROXY_PLUGIN_H_

#include <flutter_linux/flutter_linux.h>

G_BEGIN_DECLS

/// Регистрирует MethodChannel com.riotwwks.riogram/system_proxy (GProxyResolver).
void system_proxy_plugin_register(FlEngine* engine);

G_END_DECLS

#endif  // RUNNER_SYSTEM_PROXY_PLUGIN_H_
