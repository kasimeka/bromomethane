#!/usr/bin/env bash

PKGBUILD_DIR=$(mktemp -d)
trap 'rm -rf "$PKGBUILD_DIR"' EXIT

[ -d "$PKGBUILD_DIR" ] && cd "$PKGBUILD_DIR" || {
  echo "failed to initialize temporary directory"
  exit 1
}

cat <<'EOF' > PKGBUILD
# Maintainer: kasimeka
pkgname=bromomethane
pkgver=0.2.0
pkgrel=1
pkgdesc="A mod manager for Balatro - easily install and manage mods for the popular roguelike deckbuilding game. (none)"
arch=('x86_64')
url="https://github.com/kasimeka/bromomethane"
license=('GPL-3.0-only')
groups=()
depends=('cairo' 'desktop-file-utils' 'gdk-pixbuf2' 'glib2' 'gtk3' 'hicolor-icon-theme' 'libsoup3' 'openssl' 'pango' 'webkit2gtk-4.1')
options=('!strip' '!emptydirs')
install=${pkgname}.install
source_x86_64=("https://github.com/kasimeka/bromomethane/releases/download/v0.2.0/bromomethane_0.2.0_amd64.deb")
sha512sums_x86_64=('298d22d26ab783a7e819e6d534d693d22823b3eca8bf3464d6e61dc1e4da0a5d3383ddc92ff5398a9fb2446226f6829ebd32391da2b7e5b5810ae2c8a836b203')

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
