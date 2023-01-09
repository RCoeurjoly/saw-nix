{
  description = "Compara cfgs";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
    poetry2nix = {
      url = "github:RCoeurjoly/poetry2nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };
    bundlers = {
      url = "github:NixOS/bundlers";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, flake-utils, poetry2nix, bundlers }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; overlays = [ self.overlay ]; };

      customOverrides = self: super: {
        # Overrides go here
        idna = super.idna.overridePythonAttrs (
          old: {
            buildInputs = (old.buildInputs or [ ]) ++ [ self.flit-core ];
          }
        );
        wildq = super.wildq.overridePythonAttrs (
          old: {
            buildInputs = (old.buildInputs or [ ]) ++ [ self.poetry ];
          }
        );
        bitvector = super.bitvector.overridePythonAttrs (
          old: {
            buildInputs = (old.buildInputs or [ ]) ++ [ self.setuptools ];
          }
        );
      };
      my-name = "comparator";
    in {

      # Nixpkgs overlay providing the application
      overlay = nixpkgs.lib.composeManyExtensions [
        poetry2nix.overlay
        (final: prev: {
          # The application
          myapp = prev.poetry2nix.mkPoetryApplication {
            projectDir = ./.;
            overrides =
              [ prev.poetry2nix.defaultPoetryOverrides customOverrides ];
          };

          myAppEnv = pkgs.poetry2nix.mkPoetryEnv {
            projectDir = ./.;
            editablePackageSources = {
              my-app = ./src;
            };
            overrides =
              [ pkgs.poetry2nix.defaultPoetryOverrides customOverrides ];
          };

        })
      ];
      devShells.x86_64-linux.default = pkgs.myAppEnv.env.overrideAttrs (oldAttrs: {
        buildInputs = with pkgs; [ poetry jq ];
      });
      packages.x86_64-linux.comparator = pkgs.symlinkJoin {
        name = my-name;
        paths = [ self.packages.x86_64-linux.default ];
        buildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
                  wrapProgram $out/bin/${my-name} --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.coreutils self.packages.x86_64-linux.default ]}
          '';
      };
      packages.x86_64-linux.default = pkgs.myapp;
      apps.x86_64-linux.default = { type = "app"; program = "${self.packages.x86_64-linux.default}/bin/${my-name}"; };
      packages.x86_64-linux.rpm = bundlers.bundlers.x86_64-linux.toRPM self.packages.x86_64-linux.comparator;
    };
}
