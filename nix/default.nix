{ sources ? import ./sources.nix
}:
let
  # default nixpkgs
  pkgs = import sources.nixpkgs { };

  # gitignore.nix
  gitignoreSource = (import sources."gitignore.nix" { inherit (pkgs) lib; }).gitignoreSource;

  pre-commit-hooks = (import sources."pre-commit-hooks.nix");

  mach-nix = (import sources."mach-nix") {
    python = "python36";
  };

  machNix = mach-nix.mkPython {
    requirements = ''
      jupyterlab
      zipline
      matplotlib
      seaborn == 0.10.1
      ipywidgets
      ipyvuetify
      altair
      jupytext
      attrs
    '';
    providers.jupyterlab = "nixpkgs";
    packagesExtra = [
      (mach-nix.buildPythonPackage {
        src = sources."bcolz"."url";
        version = sources."bcolz"."rev";
        preBuild = ''
          # refer to https://github.com/Blosc/bcolz/issues/398
          export DISABLE_BCOLZ_AVX2=true
        '';
      })
    ];
  };

  jupyterlabExtensions = [
    "@jupyter-widgets/jupyterlab-manager@2"
    "jupyterlab-jupytext@1.2.2"
    "jupyter-vuetify"
  ];

  src = gitignoreSource ./..;
in
{
  inherit pkgs src;

  # provided by shell.nix
  devTools = {
    inherit (pkgs) niv;
    inherit (pre-commit-hooks) pre-commit;
    inherit machNix;
    # required for jupyter extensions
    inherit (pkgs) nodejs;
  };

  jupyter = {
    shellHook = ''
        APPDIR=./app
        mkdir -p $APPDIR

        ${pkgs.stdenv.lib.concatMapStrings
          (s: "jupyter labextension install --no-build --app-dir=$APPDIR ${s}; ")
          jupyterlabExtensions}
      jupyter lab build --app-dir=$APPDIR
      chmod -R +w $APPDIR/staging/
      jupyter lab build --app-dir=$APPDIR
      # start jupyterlab
      jupyter lab --app-dir=$APPDIR --notebook-dir=./notebooks
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
