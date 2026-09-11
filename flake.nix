{
  description = "Nix package for Pi - self-extensible coding agent CLI";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    let
      overlay = final: prev: {
        pi-coding-agent = final.callPackage ./package.nix { };
      };
    in
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ overlay ];
        };
      in
      {
        packages = {
          default = pkgs.pi-coding-agent;
          pi-coding-agent = pkgs.pi-coding-agent;
        };

        apps.default = {
          type = "app";
          program = "${pkgs.pi-coding-agent}/bin/pi";
        };

        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            curl
            git
            jq
            nix
            nixpkgs-fmt
            python3
          ];
        };
      }) // {
      overlays.default = overlay;
    };
}
