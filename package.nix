{ lib
, stdenv
, buildNpmPackage
, fetchFromGitHub
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
  version = "0.80.10";

  src = fetchFromGitHub {
    owner = "earendil-works";
    repo = "pi";
    rev = "v${version}";
    hash = "sha256-Vs/ndHYzFyfN4CjPV2zMYblLXe9IuM13UrPJI1VsZEQ=";
  };

  nodejs = nodejs_22;

  npmDepsHash = "sha256-XGvDNH+eilsgc0Z7ITqbitB/9RVc+WuDfCcr1pibNqk=";

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

  # Two source edits, applied in patchPhase before `npm ci`:
  #
  # 1. Neutralize husky (git-hook install) — no .git in the sandbox. Targeted,
  #    NOT --ignore-scripts (which would also skip photon-node / tsgo native
  #    install steps → subtle build break).
  #
  # 2. Strip the model-catalog generation from packages/ai's build script.
  #    Upstream's `build` runs `generate-models && generate-image-models`
  #    before tsgo; those scripts fetch models.dev / OpenRouter / Vercel AI
  #    Gateway / NVIDIA NIM. In the network-less sandbox each fetch soft-fails
  #    (non-strict) to an empty list, but the generators rmSync + overwrite the
  #    committed, populated catalogs (src/models.generated.ts,
  #    src/providers/*.models.ts, src/image-models.generated.ts) with empty
  #    ones — yielding a "green" build that ships a pi with zero models. The
  #    tag already vendors the fully-populated catalogs, so we drop the two
  #    generate steps and compile what upstream committed (deterministic,
  #    offline, no giant models.dev JSON to re-vendor). --replace-fail errors
  #    loudly if the upstream build string ever drifts.
  postPatch = ''
    substituteInPlace package.json \
      --replace-fail '"prepare": "husky"' '"prepare": ""'

    substituteInPlace packages/ai/package.json \
      --replace-fail 'npm run generate-models && npm run generate-image-models && tsgo -p tsconfig.build.json' 'tsgo -p tsconfig.build.json'
  '';

  preBuild = lib.optionalString stdenv.isLinux ''
    autoPatchelf node_modules/@typescript
  '';

  npmBuildScript = "build";  # root: tui→ai→agent→coding-agent→orchestrator

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
