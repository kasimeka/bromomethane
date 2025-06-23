#!/usr/bin/env bash

PKGBUILD_DIR=$(mktemp -d)
trap 'rm -rf "$PKGBUILD_DIR"' EXIT

# shellcheck disable=SC2015
[ -d "$PKGBUILD_DIR" ] && cd "$PKGBUILD_DIR" || {
  echo "failed to initialize temporary directory"
  exit 1
}

cat <<'EOF' > PKGBUILD
# Maintainer: kasimeka
pkgname=bromomethane
pkgver=0.1.0
pkgrel=1
pkgdesc="A mod manager for Balatro - easily install and manage mods for the popular roguelike deckbuilding game. (none)"
arch=('x86_64')
url="https://github.com/kasimeka/bromomethane"
license=('GPL-3.0-only')
groups=()
depends=('cairo' 'desktop-file-utils' 'gdk-pixbuf2' 'glib2' 'gtk3' 'hicolor-icon-theme' 'libsoup3' 'openssl' 'pango' 'webkit2gtk-4.1')
options=('!strip' '!emptydirs')
install=${pkgname}.install
source_x86_64=("https://github.com/kasimeka/bromomethane/releases/download/v0.1.0/bromomethane_0.1.0_amd64.deb")
sha512sums_x86_64=('c289ed71955a275d633520663b1256ed2d0a1e4fe9c3f33a7f27235cc066c4bbe6f68fc3081af3cea58f23b533e7dff3d24c90e6adcc4a19d077de1e2aab38bf')

package(){
	tar -xz -f data.tar.gz -C "${pkgdir}"
}
EOF

cat <<'EOF' > bromomethane.install
post_install() {
	gtk-update-icon-cache -q -t -f usr/share/icons/hicolor
	update-desktop-database -q
}

post_upgrade() {
	post_install
}

post_remove() {
	gtk-update-icon-cache -q -t -f usr/share/icons/hicolor
	update-desktop-database -q
}
EOF

makepkg -sci --noconfirm
