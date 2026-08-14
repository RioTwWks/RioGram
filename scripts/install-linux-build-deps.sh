#!/usr/bin/env bash
# Зависимости для сборки TDLib и Flutter на Linux (CI / release).
set -euo pipefail

sudo apt-get update
sudo apt-get install -y \
  build-essential \
  cmake \
  ninja-build \
  gperf \
  zlib1g-dev \
  libssl-dev \
  clang \
  pkg-config \
  libgtk-3-dev \
  libgstreamer1.0-dev \
  libgstreamer-plugins-base1.0-dev \
  libblkid-dev \
  liblzma-dev \
  zip \
  perl \
  php-cli
