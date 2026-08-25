//
// RioGram DPI bypass — реализация фрагментации, DRS и выбора профиля.
//
#include "td/mtproto/dpi_bypass/DpiBypass.h"

#include "td/utils/Random.h"
#include "td/utils/Time.h"

#include <algorithm>

namespace td {
namespace mtproto {
namespace dpi_bypass {

namespace {

char ascii_tolower(char c) {
  if (c >= 'A' && c <= 'Z') {
    return static_cast<char>(c + ('a' - 'A'));
  }
  return c;
}

bool ascii_iequals(Slice left, Slice right) {
  if (left.size() != right.size()) {
    return false;
  }
  for (size_t i = 0; i < left.size(); i++) {
    if (ascii_tolower(left[i]) != ascii_tolower(right[i])) {
      return false;
    }
  }
  return true;
}

bool ascii_iequals_suffix(Slice domain, Slice suffix) {
  if (domain.size() < suffix.size()) {
    return false;
  }
  return ascii_iequals(domain.substr(domain.size() - suffix.size()), suffix);
}

bool domain_matches_service(Slice domain, Slice suffix) {
  return ascii_iequals(domain, suffix) || ascii_iequals_suffix(domain, suffix);
}

struct DomainMapping {
  Slice suffix;
  ServiceFamily family;
};

constexpr DomainMapping kDomainMappings[] = {
    {"yandex.ru", ServiceFamily::Yandex},     {"ya.ru", ServiceFamily::Yandex},
    {"yandex.com", ServiceFamily::Yandex},   {"yandex.net", ServiceFamily::Yandex},
    {"vk.com", ServiceFamily::Vk},           {"vk.ru", ServiceFamily::Vk},
    {"vkontakte.ru", ServiceFamily::Vk},     {"userapi.com", ServiceFamily::Vk},
    {"gosuslugi.ru", ServiceFamily::Gosuslugi}, {"gu.st", ServiceFamily::Gosuslugi},
};

struct ProfilePool {
  const TlsProfile *profiles;
  size_t size;
};

constexpr TlsProfile kYandexProfiles[] = {TlsProfile::Yandex, TlsProfile::Chrome, TlsProfile::Firefox};
constexpr TlsProfile kVkProfiles[] = {TlsProfile::Vk, TlsProfile::Chrome, TlsProfile::Yandex};
constexpr TlsProfile kGosuslugiProfiles[] = {TlsProfile::Gosuslugi, TlsProfile::Yandex, TlsProfile::Chrome};
constexpr TlsProfile kGenericProfiles[] = {TlsProfile::Chrome, TlsProfile::Firefox, TlsProfile::Yandex,
                                           TlsProfile::Safari};

ProfilePool profile_pool_for_family(ServiceFamily family) {
  switch (family) {
    case ServiceFamily::Yandex:
      return {kYandexProfiles, std::size(kYandexProfiles)};
    case ServiceFamily::Vk:
      return {kVkProfiles, std::size(kVkProfiles)};
    case ServiceFamily::Gosuslugi:
      return {kGosuslugiProfiles, std::size(kGosuslugiProfiles)};
    case ServiceFamily::Generic:
    default:
      return {kGenericProfiles, std::size(kGenericProfiles)};
  }
}

TlsProfile primary_profile_for_family(ServiceFamily family) {
  switch (family) {
    case ServiceFamily::Yandex:
      return TlsProfile::Yandex;
    case ServiceFamily::Vk:
      return TlsProfile::Vk;
    case ServiceFamily::Gosuslugi:
      return TlsProfile::Gosuslugi;
    case ServiceFamily::Generic:
    default:
      return TlsProfile::Chrome;
  }
}

struct RotationState {
  size_t pool_index{0};
  double last_rotation_unix_time{0};
  int consecutive_failures{0};
};

RotationState &rotation_state_for_family(ServiceFamily family) {
  static RotationState states[4];
  return states[static_cast<size_t>(family)];
}

TlsProfile profile_from_pool(ServiceFamily family, size_t index) {
  auto pool = profile_pool_for_family(family);
  return pool.profiles[index % pool.size];
}

void advance_rotation(ServiceFamily family) {
  auto &state = rotation_state_for_family(family);
  auto pool = profile_pool_for_family(family);
  state.pool_index = (state.pool_index + 1) % pool.size;
  state.last_rotation_unix_time = Time::now();
  state.consecutive_failures = 0;
}

}  // namespace

ServiceFamily detect_service_family(Slice domain) {
  for (const auto &mapping : kDomainMappings) {
    if (domain_matches_service(domain, mapping.suffix)) {
      return mapping.family;
    }
  }
  return ServiceFamily::Generic;
}

TlsProfile pick_profile_for_domain(Slice domain) {
  if (kDpiBypassStableProxyMode) {
    return primary_profile_for_family(detect_service_family(domain));
  }
  return get_effective_profile(domain);
}

TlsProfile get_effective_profile(Slice domain) {
  auto family = detect_service_family(domain);
  auto &state = rotation_state_for_family(family);
  return profile_from_pool(family, state.pool_index);
}

void on_tls_handshake_failure(Slice domain) {
  if (!kDpiBypassAutoRotateProfiles || kDpiBypassStableProxyMode) {
    return;
  }
  auto family = detect_service_family(domain);
  auto &state = rotation_state_for_family(family);
  state.consecutive_failures++;
  advance_rotation(family);
}

void maybe_rotate_profile_on_timer(Slice domain) {
  if (!kDpiBypassAutoRotateProfiles || kDpiBypassStableProxyMode) {
    return;
  }
  auto family = detect_service_family(domain);
  auto &state = rotation_state_for_family(family);
  if (state.last_rotation_unix_time == 0) {
    state.last_rotation_unix_time = Time::now();
    return;
  }
  if (Time::now() - state.last_rotation_unix_time >= kProfileRotationIntervalSec) {
    advance_rotation(family);
  }
}

BrowserProfile pick_random_profile() {
  if (kDpiBypassStableProxyMode) {
    // DPI_BYPASS: Chrome без ECH — как PhantomProxy testclient (utls HelloChrome_Auto).
    return TlsProfile::Chrome;
  }

  // DPI_BYPASS: случайный выбор профиля при каждом подключении.
  switch (Random::fast(0, 5)) {
    case 0:
      return TlsProfile::Chrome;
    case 1:
      return TlsProfile::Firefox;
    case 2:
      return TlsProfile::Yandex;
    case 3:
      return TlsProfile::Safari;
    case 4:
      return TlsProfile::Vk;
    default:
      return TlsProfile::Gosuslugi;
  }
}

std::vector<string> fragment_client_hello(Slice packet, size_t min_parts, size_t max_parts) {
  std::vector<string> result;
  if (packet.empty()) {
    return result;
  }

  if (kDpiBypassStableProxyMode || min_parts <= 1) {
    result.emplace_back(packet.str());
    return result;
  }

  if (packet.size() < 64) {
    result.emplace_back(packet.str());
    return result;
  }

  auto parts_count = static_cast<size_t>(Random::fast(static_cast<int>(min_parts), static_cast<int>(max_parts)));
  parts_count = std::min(parts_count, packet.size() / 32);
  if (parts_count <= 1) {
    result.emplace_back(packet.str());
    return result;
  }

  // DPI_BYPASS: случайные точки разреза с минимальным размером фрагмента.
  std::vector<size_t> cuts;
  cuts.reserve(parts_count - 1);
  for (size_t i = 1; i < parts_count; i++) {
    auto min_pos = i * 32;
    auto max_pos = packet.size() - (parts_count - i) * 32;
    if (min_pos >= max_pos) {
      result.emplace_back(packet.str());
      return result;
    }
    cuts.push_back(static_cast<size_t>(Random::fast(static_cast<int>(min_pos), static_cast<int>(max_pos))));
  }
  std::sort(cuts.begin(), cuts.end());

  size_t offset = 0;
  for (auto cut : cuts) {
    result.emplace_back(packet.substr(offset, cut - offset).str());
    offset = cut;
  }
  result.emplace_back(packet.substr(offset).str());
  return result;
}

size_t pick_random_record_size(size_t default_max) {
  if (kDpiBypassStableProxyMode) {
    return default_max;
  }
  // DPI_BYPASS: варьируем размер TLS Application Data записей.
  constexpr size_t min_size = 1024;
  if (default_max <= min_size) {
    return default_max;
  }
  return static_cast<size_t>(Random::fast(static_cast<int>(min_size), static_cast<int>(default_max)));
}

}  // namespace dpi_bypass
}  // namespace mtproto
}  // namespace td
