{
  nixConfig.bash-prompt-prefix = ''(bmm) '';

  inputs = {
    gitignore = {
      url = "github:hercules-ci/gitignore.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-utils.url = "github:numtide/flake-utils";

    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    gitignore,
    ...
  }:
    flake-utils.lib.eachDefaultSystem (
      system: let
        pkgs = nixpkgs.legacyPackages.${system};

        drv = let
          cargo-toml = pkgs.lib.importTOML ./tauri/Cargo.toml;

          src = pkgs.lib.cleanSourceWith {
            name = "${pname}-${version}-clean-src";
            src = ./.;
            filter = gitignore.lib.gitignoreFilterWith {
              basePath = ./.;
              extraRules = "/.hack\n" + builtins.readFile ./.dockerignore;
            };
          };
          pname = cargo-toml.package.name;
          version = cargo-toml.package.version;

          mainProgram =
            (pkgs.lib.lists.findFirst (f: f.path == "src/main.rs") null cargo-toml.bin).name;
        in
          pkgs.rustPlatform.buildRustPackage {
            inherit src pname version;
            doCheck = false;

            buildAndTestSubdir = "tauri";
            cargoLock.lockFile = "${src}/Cargo.lock";
            cargoLock.outputHashes = {
              "fix-path-env-0.0.0" = "sha256-SHJc86sbK2fA48vkVjUpvC5FQoBOno3ylUV5J1b4dAk=";
            };

            pnpmDeps = pkgs.pnpm.fetchDeps {
              inherit pname version src;
              hash = "sha256-hhqoVpviKdszKlGoQ4UsmYRnTfG2BAk4zBEtv8bLG5s=";
            };

            nativeBuildInputs = with pkgs; [
              pkg-config
              cargo-tauri.hook

              nodePackages_latest.nodejs
              pnpm
              pnpm.configHook

              wrapGAppsHook3
            ];

            buildInputs = with pkgs;
              [openssl]
              ++ lib.optionals stdenv.isLinux [
                webkitgtk_4_1
                atk
                cairo
                gdk-pixbuf
                glib
                gtk3
                harfbuzz
                librsvg
                libsoup_3
                pango
              ]
              ++ lib.optionals stdenv.isDarwin [darwin.apple_sdk.frameworks.WebKit];

            postInstall = with pkgs;
              lib.optionalString stdenv.hostPlatform.isDarwin ''
                mkdir -p "$out/bin"
                ln -sf "$out/Applications/${pname}.app/Contents/MacOS/${pname}" "$out/bin/${mainProgram}"
              '';

            meta = {
              inherit mainProgram;
              homepage = "https://github.com/kasimeka/bromomethane";
              license = pkgs.lib.licenses.gpl3;
              platforms = with pkgs.lib.platforms; linux ++ darwin; # darwin support untested
            };
          };
      in {
        packages.default = self.packages.${system}.bromomethane;
        packages.bromomethane = drv;

        devShells.default = self.devShells.${system}.full;
        devShells.minimal = pkgs.mkShell {
          inputsFrom = [self.packages.${system}.bromomethane];
          packages = with pkgs; lib.optionals stdenv.isLinux [xdg-utils];
          shellHook = with pkgs;
            lib.optionalString stdenv.hostPlatform.isLinux ''
              export GSETTINGS_SCHEMA_DIR="${glib.getSchemaPath gtk3}"
            '';
        };
        devShells.full = pkgs.mkShell {
          inputsFrom = [self.devShells.${system}.minimal];
          packages = with pkgs;
            [
              just
              rust-analyzer
              clippy
              rustfmt

              prettierd
              eslint_d
            ]
            ++ (with nodePackages_latest; [
              svelte-language-server
              typescript-language-server
              vscode-langservers-extracted
            ]);
        };
      }
    );
}
