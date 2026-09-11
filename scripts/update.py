#!/usr/bin/env python3
from pathlib import Path
import re
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
from update_common import (  # noqa: E402
    Profile as BaseProfile,
    Target,
    UpdateError,
    Version,
    learn_hashes,
    main,
    package_version,
    select_release,
    set_named_hash,
    set_package_version,
    set_source_hash,
    source_hash,
    validate_sri,
)


class Profile(BaseProfile):
    name = "Pi"
    files = ("package.nix",)
    binary = "pi"
    repository = "earendil-works/pi"

    def current_version(self, root: Path) -> Version:
        return package_version(root)

    def discover(self, ctx, requested: Version | None) -> Target:
        version = select_release(ctx, self.repository, requested)
        metadata = ctx.http_json(f"https://registry.npmjs.org/%40earendil-works%2Fpi-ai/{version}")
        if not isinstance(metadata, dict) or metadata.get("version") != str(version):
            raise UpdateError("npm returned metadata for the wrong pi-ai version")
        distribution = metadata.get("dist")
        integrity = distribution.get("integrity") if isinstance(distribution, dict) else None
        validate_sri(integrity, "sha512")
        return Target(version, integrity)

    def prepare(self, ctx, target: Target) -> None:
        set_package_version(ctx, target.version)
        set_source_hash(ctx, source_hash(ctx, self.repository, target.version))
        ctx.replace_one(
            "package.nix",
            r'(modelData\s*=\s*fetchurl\s*\{.*?\n\s*hash\s*=\s*)"[^"]*";',
            rf'\g<1>"{target.payload}";',
            flags=re.DOTALL,
        )
        learn_hashes(
            ctx,
            {
                "npmDepsHash": (
                    f"pi-coding-agent-{target.version}-npm-deps",
                    lambda value: set_named_hash(ctx, "npmDepsHash", value),
                )
            },
        )

    def commit_subject(self, target: Target) -> str:
        return f"Update Pi to v{target.version}"


if __name__ == "__main__":
    raise SystemExit(main(Profile()))
