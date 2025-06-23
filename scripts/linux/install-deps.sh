#!/usr/bin/env sh
set -xe

apt-get install -y \
  curl
curl -fsSL https://deb.nodesource.com/setup_23.x -o nodesource_setup.sh \
  | bash

apt-get install -y \
  nodejs \
  npm \
  \
  pkg-config \
  file \
  xdg-utils \
  \
  libssl-dev \
  libglib2.0-dev \
  libgtk-3-dev \
  librsvg2-dev \
  libsoup-3.0-dev \
  libjavascriptcoregtk-4.1-dev \
  libjavascriptcoregtk-4.1-0 \
  gir1.2-javascriptcoregtk-4.1 \
  libwebkit2gtk-4.1-dev \
  libwebkit2gtk-4.1-0 \
  gir1.2-webkit2-4.1
