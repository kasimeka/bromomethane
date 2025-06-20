#!/usr/bin/env bash
set -xe

WORKDIR="$PWD/.hack/linux"
OUTDIR="${WORKDIR}/bundles/$(date --utc +%Y%m%d_%H%M%SZ)"
mkdir -p "${OUTDIR}"

docker buildx build -f "${WORKDIR}"/Dockerfile . --load -t balatro-mod-manager:temp

docker run --rm -v "${OUTDIR}:/output" balatro-mod-manager:temp bash -c 'cp /app/bundles/* /output/'
