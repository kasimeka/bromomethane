<!-- markdownlint-disable line-length no-duplicate-heading -->
# changelog

all notable changes to this project will be documented in this file. the format is based on [keep a changelog](https://keepachangelog.com/en/1.1.0/) and adheres to [semantic versioning](https://semver.org/spec/v2.0.0.html).

## [unreleased]

## [0.3.0] - 2025-07-04

### added

- an update notification popup based on the latest github release tag
  - popup can be dismissed by pressing `esc` or clicking outside it

### removed

- the security notice on first launch
- the entire balamod module :)

### changed

- resolve lint warnings in `bmm_lib`
- unify `package.json` and `Cargot.toml` as the source of truth on the project's version everywhere in js and rust respectively
- nix devshell: fix no TLS capabilities in the webview

## [0.2.0] - 2025-06-27

### changed

- `ModCard` & `ModView`: don't crop or zoom into thumbnails if they don't match the 16:9 aspect ratio
- "Installed Mods" page: prevent mod cards from jumping between sections when they're enabled/disabled
- tauri: attempt to launch the balatro through `steam` first, then `xdg-open steam://` before falling back to the `Balatro.exe` binary.

### added

- the same lints in `bmm_lib` & `bromomethane` bin crates are enforced in the `bromomethane` lib crate <!-- seriously rust, why are two files in the same directory considered two separate crates? -->
- enforced default `js`, `ts` & `svelte` eslint rules on the frontend

### removed

- support for `tar` and `gz` mod zips, only `zip` is supported now

## [0.1.0] - 2025-06-23

### changed

- `Mods` component:
  - thumbnails are lazily loaded after their cards are rendered in the UI, instead of waiting for the entire index to download before showing any usable UI
  - mods are sorted by last updated instead of alphabetical
  - the search finds mods by name, author and description, not just name and author
- all of the three caching layers are unused and will eventually be replaced
- the frontend dev server is run on node with pnpm instead of bun
- a good bunch of rust lints are enforced, and stricter code quality checks will be added for the FE

### added

- linux support, the project builds and runs on linux with no missing features compared to other platforms
- support for tracking mods' last updated time

### removed

- discord rich presence
- the animated shader background
