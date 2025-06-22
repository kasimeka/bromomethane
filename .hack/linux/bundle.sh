#!/usr/bin/env bash
set -xe

WORKDIR="$PWD/.hack/linux"
OUTDIR="${WORKDIR}/bundles/$(date --utc +%Y%m%d_%H%M%SZ)"
mkdir -p "${OUTDIR}"

docker buildx build -f "${WORKDIR}"/Dockerfile . --load -t bromomethane:trash

docker run --rm -v "${OUTDIR}:/output" bromomethane:trash bash -c 'cp /app/bundles/* /output/'

DEB="$(ls -1t "$OUTDIR/"*.deb | head -n1)"

VERSION="$(jq -r '.version' package.json)"
SHA512SUM="$(sha512sum "$DEB" | cut -d' ' -f1)"

sed \
  -e 's/@version@/'"$VERSION"'/g' \
  -e 's/@sha512sum@/'"$SHA512SUM"'/g' \
  .hack/linux/pkgbuild/PKGBUILD.tmpl \
  > .hack/linux/pkgbuild/PKGBUILD
