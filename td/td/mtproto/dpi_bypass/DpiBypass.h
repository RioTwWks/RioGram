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

// DPI_BYPASS: профили маскировки TLS ClientHello.
enum class BrowserProfile { Chrome, Firefox, Yandex, Safari };

BrowserProfile pick_random_profile();

// DPI_BYPASS: разбить ClientHello на 2–3 TCP-фрагмента.
std::vector<string> fragment_client_hello(Slice packet, size_t min_parts = 2, size_t max_parts = 3);

// DPI_BYPASS: динамический размер TLS-записи (DRS).
size_t pick_random_record_size(size_t default_max);

}  // namespace dpi_bypass
}  // namespace mtproto
}  // namespace td
