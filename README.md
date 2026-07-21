# pi-cli-nix

Always up-to-date Nix package for [Pi](https://github.com/earendil-works/pi) — a self-extensible, interactive coding-agent CLI (`pi`) with a unified multi-provider LLM API.

> **Beta**: This project is under active development by a solo maintainer and may break between updates. Use at your own risk. Contributions welcome — open issues or PRs.

## Why this package?

Pi is not yet packaged in nixpkgs. This flake lets you:

1. **Always have the latest version** — update as soon as a new release drops
2. **Declarative installation** — managed in your NixOS or Home Manager config
3. **Reproducible builds** — built from source via `buildNpmPackage`

## Project Structure

| File | Purpose |
|---|---|
| `flake.nix` | Flake definition: inputs (nixpkgs, flake-utils), overlay, packages, app, devShell |
| `package.nix` | Build recipe: fetches the GitHub source, builds the workspace monorepo, ships the tree + `bin/pi` wrapper |
| `default.nix` | Non-flake entry point (NUR-compatible) |
| `flake.lock` | Pinned inputs |
| `update.sh` | Autonomous update workflow driven by Claude Code |
| `.gitignore` | Excludes Nix build artifacts and editor files |

## Quick Start

```bash
# Run directly without installing
nix run github:selfhost-it/pi-cli-nix

# Install to your profile
nix profile install github:selfhost-it/pi-cli-nix
```

## NixOS / Home Manager Integration

### Add to your flake inputs

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    pi = {
      url = "github:selfhost-it/pi-cli-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
}
```

### Apply the overlay

```nix
{
  nixpkgs.overlays = [
    pi.overlays.default
  ];
}
```

### Add to your packages

NixOS (`configuration.nix`):

```nix
environment.systemPackages = with pkgs; [
  pi-coding-agent
];
```

Home Manager (`home.nix`):

```nix
home.packages = with pkgs; [
  pi-coding-agent
];
```

## Building Locally

```bash
git clone git@github.com:selfhost-it/pi-cli-nix.git
cd pi-cli-nix
nix build .

# Test
./result/bin/pi --version

# Or run directly
nix run .
```

## Updating to a new Pi version

1. Change `version` in `package.nix` (e.g. `"0.80.11"`).
2. Set `hash = "";` and run `nix build .` — it fails and prints the correct hash. Paste it back.
3. Set `npmDepsHash = "";` and run `nix build .` — again paste the hash from the error.
4. Update the `modelData` hash: `curl -s "https://registry.npmjs.org/@earendil-works/pi-ai/<VERSION>" | jq -r .dist.integrity` and paste the `sha512-...` value into `modelData.hash` (its URL tracks `version` automatically).
5. Run `nix build .` again — it should succeed.
6. Verify `./result/bin/pi --version`, then commit and push.

The autonomous workflow `./update.sh` performs all of these steps using Claude Code.

## Technical Details

- **Source**: Built from the [earendil-works/pi](https://github.com/earendil-works/pi) GitHub repo (tag `v<VERSION>`).
- **Builder**: `buildNpmPackage` running the root `build:offline` script, which compiles the workspace packages in order (`tui → ai → agent → storage/sqlite-node → coding-agent → server`) with `tsgo`, without touching the network.
- **Model catalog**: since 0.81.x upstream no longer commits the per-provider model data (`packages/ai/src/providers/data/`) to git; it is normally hydrated from live APIs at build time. We instead vendor the npm-published `@earendil-works/pi-ai` tarball of the same version (fixed-output `fetchurl`) and restore its `dist/providers/data` before the build. The build's own `check:model-data` step verifies the vendored data against the committed structure and manifest hashes.
- **Runtime**: Node.js 22 (upstream `engines.node` is `>=22.19.0`).
- **Not bundled**: `pi` (`packages/coding-agent/dist/cli.js`) imports sibling workspace packages (`@earendil-works/pi-ai`, `pi-tui`, `pi-agent-core`) at runtime. A custom `installPhase` copies the built tree with its relative workspace symlinks intact (`cp -a`) and exposes `bin/pi` via `makeWrapper node --add-flags cli.js`.
- **Native/asset deps**: `@silvia-odwyer/photon-node` ships a `.wasm` (portable, no compilation). On Linux the prebuilt `tsgo` build tool is patched with `autoPatchelfHook`.
- **Binary**: `pi` (at `$out/bin/pi`).

## License

Pi is licensed under [MIT](https://github.com/earendil-works/pi/blob/main/LICENSE).

---

Maintained by [self-host.it](https://self-host.it)
