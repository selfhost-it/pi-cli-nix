# Questo file permette a chi non usa i Flakes (come il NUR) di accedere al pacchetto.
{ pkgs ? import <nixpkgs> { } }:

{
  pi-coding-agent = pkgs.callPackage ./package.nix { };
}
