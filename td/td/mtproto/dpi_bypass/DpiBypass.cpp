//
// RioGram DPI bypass — реализация фрагментации и DRS.
//
#include "td/mtproto/dpi_bypass/DpiBypass.h"

#include "td/utils/Random.h"

#include <algorithm>

namespace td {
namespace mtproto {
namespace dpi_bypass {

BrowserProfile pick_random_profile() {
  if (kDpiBypassStableProxyMode) {
    // DPI_BYPASS: Yandex-профиль без ECH — PhantomProxy с reject_fronting отклоняет ECH (0xfe0d).
    // utls HelloChrome_Auto тоже без ECH; наш Chrome-профиль содержит ECH и не подходит.
    return BrowserProfile::Yandex;
  }

  // DPI_BYPASS: случайный выбор профиля при каждом подключении.
  switch (Random::fast(0, 3)) {
    case 0:
      return BrowserProfile::Chrome;
    case 1:
      return BrowserProfile::Firefox;
    case 2:
      return BrowserProfile::Yandex;
    default:
      return BrowserProfile::Safari;
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
