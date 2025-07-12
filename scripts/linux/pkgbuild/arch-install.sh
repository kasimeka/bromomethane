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
pkgver=0.4.0
pkgrel=1
pkgdesc="A mod manager for Balatro - easily install and manage mods for the popular roguelike deckbuilding game. (none)"
arch=('x86_64')
url="https://github.com/kasimeka/bromomethane"
license=('GPL-3.0-only')
groups=()
depends=('cairo' 'desktop-file-utils' 'gdk-pixbuf2' 'glib2' 'gtk3' 'hicolor-icon-theme' 'libsoup3' 'openssl' 'pango' 'webkit2gtk-4.1')
options=('!strip' '!emptydirs')
install=${pkgname}.install
source_x86_64=("https://github.com/kasimeka/bromomethane/releases/download/v0.4.0/bromomethane_0.4.0_amd64.deb")
sha512sums_x86_64=('ee3d923bad5816f7ab5cef6c63eb86b5e9694efd78f48e7e77e75857def79796993ab605357b3487ac0608f6d67cd33eeccfbeaf9dd60112d38c7091101241f8')

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
