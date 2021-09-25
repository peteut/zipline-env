{ sources ? import ./sources.nix
}:
let
  # default nixpkgs
  pkgs = import sources.nixpkgs { };

  niv = import sources.niv { };

  # gitignore.nix
  gitignoreSource = (import sources."gitignore.nix" { inherit (pkgs) lib; }).gitignoreSource;

  pre-commit-hooks = (import sources."pre-commit-hooks.nix");

  mach-nix = (import sources."mach-nix") {
    python = "python38";
  };

  machNix = mach-nix.mkPython {
    requirements = ''
      jupyterlab
      zipline-reloaded
      ipyvuetify
      altair
      jupytext
      attrs
    '';
    providers.jupyterlab = "wheel";
    providers.zipline-reloaded = "wheel";
    _.ta-lib.buildInputs.add = [
      (pkgs.stdenv.mkDerivation {
        pname = sources.ta-lib.repo;
        version = sources.ta-lib.rev;
        src = sources.ta-lib;
        nativeBuildInputs = with pkgs; [
          autoreconfHook
        ];
        patches = [
          ./../ta-lib.patch
        ];
      })
    ];
  };

  src = gitignoreSource ./..;
in
{
  inherit pkgs src;

  # provided by shell.nix
  devTools = {
    inherit (niv) niv;
    inherit (pkgs) glibcLocales;
    inherit (pre-commit-hooks) pre-commit;
    inherit machNix;
    # required for jupyter extensions
    inherit (pkgs) nodejs;
  };

  jupyter = {
    shellHook = ''
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
