#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp_home="$(mktemp -d)"
trap 'rm -rf "${tmp_home}"' EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

mkdir -p "${tmp_home}/bin"
cat > "${tmp_home}/bin/claude-real" <<'SH'
#!/usr/bin/env bash
printf 'real:%s\n' "$*"
SH
chmod +x "${tmp_home}/bin/claude-real"

cat > "${tmp_home}/bin/claudepod-sync-config" <<'SH'
#!/usr/bin/env bash
printf 'sync-ran\n' > "${HOME}/sync.log"
SH
chmod +x "${tmp_home}/bin/claudepod-sync-config"

output="$(
  env \
    HOME="${tmp_home}" \
    OPENPOD_CLAUDE_REAL_BIN="${tmp_home}/bin/claude-real" \
    OPENPOD_CLAUDE_SYNC_BIN="${tmp_home}/bin/claudepod-sync-config" \
    bash "${repo_root}/bin/claude" --version
)"

[[ "${output}" == "real:--version" ]] || fail "claude wrapper did not exec the real binary"
[[ -f "${tmp_home}/sync.log" ]] || fail "claudepod sync hook did not run before claude"
