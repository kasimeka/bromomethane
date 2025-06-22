<!-- markdownlint-disable line-length -->
# bromomethane

a fork of [the Balatro Mod Manager by Skyline](https://github.com/skyline69/balatro-mod-manager/) that includes all my contributions that are held back in feature branches or were lost/broken by rebase mistakes, as well as a space for experimenting with suggestions and feature requests that BMM's author refused. i've put in some work to clean up code i don't like and remove features i think are unneccessary, and i intend to work on bigger cleanups and refactors.

## mod submission

to add your mods to bromomethane or BMM, follow the instructions at [the Balatro Mod Index](https://github.com/skyline69/balatro-mod-index).

## notable changes from BMM

- mod thumbnails are lazily loaded after mod cards are rendered in the UI, unlike BMM which makes you wait for everything in the index to download before any usable interface is shown
- mods are sorted by last updated instead of alphabetical
- all of the three caching layers are unused and will eventually be replaced
- discord rich presence and the animated background were removed
- the frontend dev server is run on node with pnpm instead of bun
- a good bunch of rust lints are enforced, and stricter code quality checks will be added for the FE
- linux support is considered first class and resides in the main branch
