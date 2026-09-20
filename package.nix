{ lib
, stdenv
, buildNpmPackage
, fetchFromGitHub
, fetchurl
, nodejs_22
, makeWrapper
, autoPatchelfHook
, pkg-config
, cairo
, pango
, libjpeg
, giflib
, librsvg
, pixman
}:

buildNpmPackage rec {
  pname = "pi-coding-agent";
  version = "0.86.1";

  src = fetchFromGitHub {
    owner = "earendil-works";
    repo = "pi";
    rev = "v${version}";
    hash = "sha256-/7+VoRfXdeOwtiNXQYOKg5OHeKuNLIHfODGDNBhWop0=";
  };

  nodejs = nodejs_22;

  # Since 0.81.x upstream no longer commits packages/ai/src/providers/data
  # (per-provider model JSON + .manifest.json) to git; `hydrate:model-data`
  # fetches it from live APIs (models.dev / OpenRouter / ...) — impossible in
  # the sandbox and non-reproducible anyway. The npm-published pi-ai tarball
  # of the SAME version ships that data verbatim under dist/providers/data
  # (build:offline copies it there at release time), so we vendor it from the
  # registry as a fixed-output fetch and restore it into src/ in preBuild.
  # The build's own check:model-data step then verifies every file against
  # the manifest + committed structure hashes — a stale vendor fails loudly.
  # On bump: hash = ""; then nix build learns it, or take .dist.integrity
  # from `curl -s https://registry.npmjs.org/@earendil-works/pi-ai/<VERSION>`.
  modelData = fetchurl {
    url = "https://registry.npmjs.org/@earendil-works/pi-ai/-/pi-ai-${version}.tgz";
    hash = "sha512-1XHhI6D/fyQdsBieHC/E/4zGKVOoGe4yDyX67VXvzoYkFsX/qE7NpZE7E1RC8e6Bz8B9oG/P+MQFXikv2/BGEg==";
  };

  npmDepsHash = "sha256-VxjYw4lN/w0sDboihHAKEhdJFzJa09qZo7vavkTkBuw=";

  # tsgo (@typescript/native-preview) is a prebuilt Go binary. On Linux its
  # hardcoded loader must be patched before the build invokes it; darwin
  # Mach-O binaries run as-is, and autoPatchelfHook is Linux-only.
  # pkg-config is here for node-gyp (canvas — see buildInputs below).
  nativeBuildInputs = [ makeWrapper pkg-config ]
    ++ lib.optionals stdenv.isLinux [ autoPatchelfHook ];
  dontAutoPatchelf = true;

  # canvas@3.2.3 is a devDependency of packages/ai (test-only), but it is
  # hoisted, non-optional, and has a node-gyp install script, so `npm ci`
  # compiles it from source (its prebuilt-binary download fails offline in the
  # sandbox and falls back to a source build). node-gyp needs pkg-config +
  # cairo/pango/pixman (mandatory) and jpeg/gif/rsvg (optional features).
  # We can't drop canvas without desyncing package-lock.json from `npm ci`, so
  # we satisfy its native deps instead. NOTE (Task 2+): this drags a large
  # graphics stack (librsvg etc.) into the closure for a test-only dep — a
  # future pass could patch canvas out of the workspace + regen the lockfile.
  buildInputs = [ cairo pango libjpeg giflib librsvg pixman ];

  # One source edit, applied in patchPhase before `npm ci`:
  # Neutralize husky (git-hook install) — no .git in the sandbox. Targeted,
  # NOT --ignore-scripts (which would also skip photon-node / tsgo native
  # install steps → subtle build break).
  #
  # The model-catalog problem (upstream's `build` fetches models.dev /
  # OpenRouter / Vercel AI Gateway / NVIDIA NIM and would overwrite the
  # committed catalogs with empty ones in the network-less sandbox) is solved
  # since 0.81.x by upstream's own `build:offline` script: it validates the
  # committed model data (check:model-data, purely local) and compiles it with
  # tsgo — no network, deterministic. See npmBuildScript below.
  postPatch = ''
    substituteInPlace package.json \
      --replace-fail '"prepare": "husky"' '"prepare": ""'
  '';

  preBuild = ''
    tar -xzf $modelData -C packages/ai/src/providers \
      --strip-components=3 package/dist/providers/data
  '' + lib.optionalString stdenv.isLinux ''
    autoPatchelf node_modules/@typescript
  '';

  # root: tui→ai(offline)→agent→storage/sqlite-node→coding-agent→server
  npmBuildScript = "build:offline";

  # coding-agent/dist/cli.js imports sibling workspace packages at runtime;
  # ship the built tree with relative node_modules/@earendil-works/* symlinks
  # intact (cp -a, not -rL). No npm prune in v1 (it corrupts those symlinks).
  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/pi
    cp -a packages package.json package-lock.json node_modules $out/lib/pi/

    makeWrapper ${nodejs}/bin/node $out/bin/pi \
      --add-flags $out/lib/pi/packages/coding-agent/dist/cli.js \
      --prefix NODE_PATH : $out/lib/pi/node_modules

    runHook postInstall
  '';

  meta = with lib; {
    description = "Pi - self-extensible coding agent CLI";
    homepage = "https://github.com/earendil-works/pi";
    license = licenses.mit;
    platforms = platforms.unix;
    mainProgram = "pi";
  };
}
