{ sources ? import ./sources.nix
}:
let
  # default nixpkgs
  pkgs = import sources.nixpkgs { config.allowUnfree = true; };

  # gitignore.nix
  gitignoreSource = (import sources."gitignore.nix" { inherit (pkgs) lib; }).gitignoreSource;

  pre-commit-hooks = (import sources."pre-commit-hooks.nix");

  mach-nix = (import sources."mach-nix") {
    python = "python39";
    inherit pkgs;
  };

  machNix = mach-nix.mkPython {
    requirements = ''
      jupyterlab
      zipline-reloaded
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
    providers.zipline-reloaded = "wheel";
    _.ta-lib.buildInputs.add = [
      (pkgs.stdenv.mkDerivation {
        pname = sources.ta-lib.repo;
        version = sources.ta-lib.rev;
        src = sources.ta-lib;
        nativeBuildInputs = builtins.attrValues {
          inherit (pkgs) autoreconfHook;
        };
        patches = [
          ./../ta-lib.patch
        ];
      })
    ];
    providers.tda-api = "sdist";
    _.tda-api.src = sources.tda-api;
    _.tda-api.patches = [
      ./../tda-generate-token-shun-selenium.patch
    ];
    _.yfinance.src = sources.yfinance;
  };

  src = gitignoreSource ./..;
in
{
  inherit pkgs src;

  # provided by shell.nix
  devTools = {
    inherit (pkgs) niv glibcLocales;
    inherit (pre-commit-hooks) pre-commit;
    inherit machNix;
    # needed to grab an API token
    inherit (pkgs) google-chrome chromedriver;
  };

  jupyter = {
    shellHook = ''
      # Tells pip to put packages into $PIP_PREFIX instead of the usual locations.
      # See https://pip.pypa.io/en/stable/user_guide/#environment-variables.
      export PIP_PREFIX=$(pwd)/_build/pip_packages
      export PYTHONPATH="$PIP_PREFIX/${pkgs.python3.sitePackages}:$PYTHONPATH"
      export PATH="$PIP_PREFIX/bin:$PATH"
      unset SOURCE_DATE_EPOCH

      # start jupyterlab
      jupyter lab --notebook-dir=./notebooks
    '';
  };

  ci = {
    pre-commit-check = pre-commit-hooks.run {
      inherit src;
      hooks = {
        shellcheck.enable = true;
        nixpkgs-fmt.enable = true;
        nix-linter.enable = true;
        black.enable = true;
      };
      # generated files
      excludes = [ "^nix/sources\.nix$" ];
    };
  };
}
