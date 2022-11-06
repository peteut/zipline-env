{
  description = "zipline-env";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-22.05";
    flake-utils.url = "github:numtide/flake-utils";
    pre-commit-hooks.url = "github:cachix/pre-commit-hooks.nix";
    pypi-deps-db = {
      url = "github:DavHau/pypi-deps-db";
      flake = false;
    };
    mach-nix = {
      url = "github:DavHau/mach-nix/3.5.0";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-utils.follows = "flake-utils";
        pypi-deps-db.follows = "pypi-deps-db";
      };
    };
    tda-api = {
      url = "github:alexgolec/tda-api/v.1.5.0";
      flake = false;
    };
    ta-lib = {
      url = "github:TA-Lib/ta-lib";
      flake = false;
    };
  };

  outputs =
    { nixpkgs, flake-utils, pre-commit-hooks, mach-nix, ... }@inputs:
    let
      inherit (flake-utils.lib) eachSystem;
      supportedSystems =
        builtins.attrValues { inherit (flake-utils.lib.system) x86_64-linux; };
    in
    eachSystem supportedSystems (system:
    let
      pkgs = nixpkgs.legacyPackages.${system};
      python = "python39";
      pre-commit = pre-commit-hooks.lib.${system};
      inherit (mach-nix.lib.${system}) mkPython;
      pyEnv = mkPython {
        inherit python;
        requirements = ''
          jupyterlab
          zipline-reloaded
          pyfolio-reloaded
          tables
          ipyvuetify
          altair
          jupytext
          attrs
          selenium
          TA-lib
          pandas-datareader
          yfinance
          tda-api
          pip
        '';
        providers.jupyterlab = "wheel";
        providers.selenium = "wheel";
        providers.zipline-reloaded = "wheel";
        _.ta-lib.buildInputs.add = [
          (pkgs.stdenv.mkDerivation {
            name = "ta-lib";
            src = inputs.ta-lib;
            nativeBuildInputs =
              builtins.attrValues { inherit (pkgs) autoreconfHook; };
            patches = [ ./ta-lib.patch ];
          })
        ];
        providers.tda-api = "sdist";
        _.tda-api.src = inputs.tda-api;
        _.tda-api.patches = [ ./tda-generate-token-shun-selenium.patch ];
      };

      jupyterlab = {
        shellHook = ''
          # Tells pip to put packages into $PIP_PREFIX instead of the usual locations.
          # See https://pip.pypa.io/en/stable/user_guide/#environment-variables.
                export PIP_PREFIX=$PWD/_build/pip_packages
                export PYTHONPATH="$PIP_PREFIX/${pkgs.python3.sitePackages}:$PYTHONPATH"
                export PATH="$PIP_PREFIX/bin:$PATH"
                unset SOURCE_DATE_EPOCH

          # start jupyterlab
                jupyter lab --notebook-dir=./notebooks
        '';
      };

      checks = {
        pre-commit-check = pre-commit.run {
          src = ./.;
          hooks = {
            shellcheck.enable = true;
            nixpkgs-fmt.enable = true;
            nix-linter.enable = true;
            black.enable = true;
          };
          # generated files
          excludes = [ "^nix/sources.nix$" ];
        };
      };

    in
    {
      devShells.default = pkgs.mkShell {
        src = ./.;
        buildInputs = [ pyEnv ];
        shellHook = ''
          ${jupyterlab.shellHook}
          ${checks.pre-commit-check.shellHook}
        '';
      };
    });
}
