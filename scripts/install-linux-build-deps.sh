#!/usr/bin/env bash
# Зависимости для сборки TDLib и Flutter на Linux (CI / release).
set -euo pipefail

if command -v apt-get >/dev/null 2>&1; then
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
    libunwind-dev \
    libgstreamer1.0-dev \
    libgstreamer-plugins-base1.0-dev \
    libblkid-dev \
    liblzma-dev \
    zip \
    perl \
    php-cli
elif command -v pacman >/dev/null 2>&1; then
  sudo pacman -Syu --needed --noconfirm \
    base-devel \
    cmake \
    ninja \
    gperf \
    zlib \
    openssl \
    clang \
    pkgconf \
    gtk3 \
    libunwind \
    gstreamer \
    gst-plugins-base \
    util-linux \
    xz \
    zip \
    perl \
    php
else
  echo "Unsupported Linux distro: install build deps manually (need cmake, ninja, gperf, openssl, clang, gtk3, libunwind, gstreamer, perl, php)." >&2
  exit 1
fi
