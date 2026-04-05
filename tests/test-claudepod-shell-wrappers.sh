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

output="$(
  env \
    HOME="${tmp_home}" \
    OPENPOD_CLAUDE_REAL_BIN="${tmp_home}/bin/claude-real" \
    bash "${repo_root}/bin/claude" --version
)"

[[ "${output}" == "real:--version" ]] || fail "claude wrapper did not exec the real binary"
