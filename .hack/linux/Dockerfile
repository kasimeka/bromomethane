FROM ubuntu:noble AS ubuntu


FROM ubuntu AS base

COPY .hack/linux/install-deps.sh .
RUN apt-get update && ./install-deps.sh && apt-get clean && rm -rf /var/lib/apt/lists/*
ENV PKG_CONFIG_PATH="/usr/lib/pkgconfig:/usr/lib/x86_64-linux-gnu/pkgconfig"

RUN npm i -g corepack && corepack enable pnpm
ENV PNPM_HOME="/pnpm"
ENV PATH="$PNPM_HOME:$PATH"

RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
  | sh -s -- -y --profile minimal
ENV PATH="/root/.cargo/bin:${PATH}"


FROM base AS builder

WORKDIR /app/src

COPY package.json pnpm-lock.yaml ./
RUN --mount=type=cache,id=pnpm,target=/pnpm/store pnpm install --frozen-lockfile

COPY . .
RUN \
    --mount=type=cache,target=/app/src/tauri/target/ \
    --mount=type=cache,target=/app/src/bmm-lib/target/ \
    --mount=type=cache,target=/root/.cargo/registry/cache/git/db \
    --mount=type=cache,target=/root/.cargo/registry/cache/registry/ \
  pnpm tauri build --target x86_64-unknown-linux-gnu --verbose && \
  mkdir /app/bundles && mv \
    tauri/target/x86_64-unknown-linux-gnu/release/bundle/deb/*.deb \
    tauri/target/x86_64-unknown-linux-gnu/release/bundle/rpm/*.rpm \
    tauri/target/x86_64-unknown-linux-gnu/release/bundle/appimage/*.AppImage \
    /app/bundles


FROM ubuntu AS output

COPY --from=builder /app/bundles /app/bundles
