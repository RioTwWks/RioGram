//
// RioGram DPI bypass — рандомизация ClientHello, фрагментация, DRS.
//
#pragma once

#include "td/utils/common.h"
#include "td/utils/Slice.h"

#include <vector>

namespace td {
namespace mtproto {
namespace dpi_bypass {

// DPI_BYPASS: режим отладки совместимости с PhantomProxy / StealthGate.
// true  — профиль по домену маскировки, ClientHello одним TCP-сегментом (без ECH).
// false — полный DPI bypass: ротация профилей + фрагментация ClientHello.
constexpr bool kDpiBypassStableProxyMode = true;

// DPI_BYPASS: автосмена TLS-отпечатка по таймеру и при ошибках handshake.
constexpr bool kDpiBypassAutoRotateProfiles = true;

// DPI_BYPASS: интервал плановой ротации профиля (секунды).
constexpr int kProfileRotationIntervalSec = 1800;

// DPI_BYPASS: профили маскировки TLS ClientHello.
enum class TlsProfile { Chrome, Firefox, Yandex, Safari, Vk, Gosuslugi };

// DPI_BYPASS: семейство сервиса по SNI из ee-секрета прокси.
enum class ServiceFamily { Generic, Yandex, Vk, Gosuslugi };

ServiceFamily detect_service_family(Slice domain);

TlsProfile pick_profile_for_domain(Slice domain);

TlsProfile get_effective_profile(Slice domain);

void on_tls_handshake_failure(Slice domain);

void maybe_rotate_profile_on_timer(Slice domain);

// Совместимость со старым именем.
using BrowserProfile = TlsProfile;

BrowserProfile pick_random_profile();

// DPI_BYPASS: разбить ClientHello на 2–3 TCP-фрагмента.
std::vector<string> fragment_client_hello(Slice packet, size_t min_parts = 2, size_t max_parts = 3);

// DPI_BYPASS: динамический размер TLS-записи (DRS).
size_t pick_random_record_size(size_t default_max);

}  // namespace dpi_bypass
}  // namespace mtproto
}  // namespace td
