#!/usr/bin/env bash
# update.sh — Automatically update pi-cli-nix to the latest upstream release
# using Claude Code in non-interactive mode.
#
# Prerequisites:
#   - claude CLI installed and on PATH
#   - One-time acceptance of --dangerously-skip-permissions
#     (run: claude --dangerously-skip-permissions  and then /exit)
#
# Usage:
#   ./update.sh            # run the update
#   ./update.sh --dry-run  # print the command without executing

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PROMPT=$(cat <<'EOF'
Update pi-cli-nix to the latest upstream release.

1. Check the latest tag:
   curl -s "https://api.github.com/repos/earendil-works/pi/tags" \
     | jq -r '.[].name | select(test("^v[0-9]"))' | head -1
   Do NOT use `gh`, it may not be authenticated.

2. Compare with the current `version` in `package.nix` — if already up to date, stop.

3. Update `package.nix`:
   a. Set `version` to the new value (without leading `v`).
   b. Set `hash = "";` -> run `nix build . 2>&1` -> find the line containing `got:` and extract the SRI hash (sha256-...=) -> update `hash`.
   c. Set `npmDepsHash = "";` -> run `nix build . 2>&1` -> extract the correct hash from `got:` -> update `npmDepsHash`.
   d. Update the `modelData` fetchurl hash (vendored pi-ai npm tarball; its URL tracks `version` automatically):
      curl -s "https://registry.npmjs.org/@earendil-works/pi-ai/<VERSION>" | jq -r .dist.integrity
      Put the resulting `sha512-...` string into `modelData.hash`.

4. Run `nix build .` — this must succeed with no errors.

5. Verify: `./result/bin/pi --version` — must print the new version (NOT an error).

6. Scan all tracked files (`git ls-files`) for passwords, tokens, API keys, private keys, or sensitive information — abort if found. Content-addressable hashes are NOT secrets.

7. Commit: git add -A && git commit -m "Update pi to v<VERSION>"

8. Push: GIT_SSH_COMMAND="ssh -i ~/.ssh/self-host-github" git push origin main
EOF
)

if [[ "${1:-}" == "--dry-run" ]]; then
    echo "Would run:"
    echo "  cd $SCRIPT_DIR"
    echo "  claude -p <prompt> --dangerously-skip-permissions"
    echo ""
    echo "Prompt:"
    echo "$PROMPT"
    exit 0
fi

cd "$SCRIPT_DIR"
exec claude -p "$PROMPT" --dangerously-skip-permissions
