#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
module="${repo_root}/modules/tools/ripgrep.sh"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

brew_prefix="${tmp_dir}/homebrew"
fake_brew="${brew_prefix}/bin/brew"
mkdir -p "$(dirname "${fake_brew}")"
resolved_brew_prefix="$(cd "${brew_prefix}" && pwd -P)"
cat > "${fake_brew}" <<'BREW'
#!/usr/bin/env bash
set -euo pipefail

state="${OHMYDEVPOD_TEST_BREW_STATE}"
case "${1:-}" in
  --prefix)
    cd "$(dirname "$0")/.." && pwd -P
    ;;
  list)
    [[ -d "${state}" ]]
    ;;
  install)
    mkdir -p "${state}"
    ;;
  upgrade)
    [[ -d "${state}" ]]
    ;;
  uses)
    [[ "${OHMYDEVPOD_TEST_BREW_USES_FAIL:-0}" != "1" ]] || exit 2
    [[ -z "${OHMYDEVPOD_TEST_BREW_DEPENDANTS:-}" ]] \
      || printf '%s\n' "${OHMYDEVPOD_TEST_BREW_DEPENDANTS}"
    ;;
  uninstall)
    rm -rf "$(dirname "${state}")"
    ;;
  *)
    exit 2
    ;;
esac
BREW
chmod +x "${fake_brew}"

managed_home="${tmp_dir}/managed-home"
managed_state="${brew_prefix}/Cellar/ripgrep/1.0.0"
mkdir -p "${managed_home}"
env \
  HOME="${managed_home}" \
  PATH="/usr/bin:/bin" \
  OHMYDEVPOD_BREW_BIN="${fake_brew}" \
  OHMYDEVPOD_TEST_BREW_STATE="${managed_state}" \
  "${module}" install

[[ -d "${managed_state}" ]] || fail "install should create the fake formula"
env \
  HOME="${managed_home}" \
  PATH="/usr/bin:/bin" \
  OHMYDEVPOD_BREW_BIN="${fake_brew}" \
  OHMYDEVPOD_TEST_BREW_STATE="${managed_state}" \
  "${module}" managed

rm -rf "${managed_state}"
env \
  HOME="${managed_home}" \
  PATH="/usr/bin:/bin" \
  OHMYDEVPOD_BREW_BIN="${fake_brew}" \
  OHMYDEVPOD_TEST_BREW_STATE="${managed_state}" \
  "${module}" update
[[ -d "${managed_state}" ]] || fail "update should repair a damaged managed formula"

if env \
  HOME="${managed_home}" \
  PATH="/usr/bin:/bin" \
  OHMYDEVPOD_BREW_BIN="${fake_brew}" \
  OHMYDEVPOD_TEST_BREW_STATE="${managed_state}" \
  OHMYDEVPOD_TEST_BREW_DEPENDANTS="dependent-formula" \
  "${module}" uninstall >/dev/null 2>&1; then
  fail "uninstall should reject Homebrew formulas with installed dependants"
fi

if env \
  HOME="${managed_home}" \
  PATH="/usr/bin:/bin" \
  OHMYDEVPOD_BREW_BIN="${fake_brew}" \
  OHMYDEVPOD_TEST_BREW_STATE="${managed_state}" \
  OHMYDEVPOD_TEST_BREW_USES_FAIL=1 \
  "${module}" uninstall >/dev/null 2>&1; then
  fail "uninstall should fail closed when Homebrew dependency inspection fails"
fi
[[ -d "${managed_state}" ]] || fail "dependency inspection failure must preserve the formula"

external_home="${tmp_dir}/external-home"
external_state="${tmp_dir}/external-formula"
mkdir -p "${external_home}"
touch "${external_state}"
if env \
  HOME="${external_home}" \
  PATH="/usr/bin:/bin" \
  OHMYDEVPOD_BREW_BIN="${fake_brew}" \
  OHMYDEVPOD_TEST_BREW_STATE="${external_state}" \
  "${module}" uninstall >/dev/null 2>&1; then
  fail "uninstall should reject an external formula"
fi
[[ -f "${external_state}" ]] || fail "external formula must remain installed"

for component in yq gh; do
  module="${repo_root}/modules/tools/${component}.sh"
  formula_home="${tmp_dir}/${component}-home"
  formula_state="${brew_prefix}/Cellar/${component}/1.0.0"
  marker="${formula_home}/.local/state/oh-my-devpod/managed/${component}"
  mkdir -p "${formula_home}"

  env \
    HOME="${formula_home}" \
    PATH="/usr/bin:/bin" \
    OHMYDEVPOD_BREW_BIN="${fake_brew}" \
    OHMYDEVPOD_TEST_BREW_STATE="${formula_state}" \
    "${module}" install

  [[ -d "${formula_state}" ]] || fail "${component} install should create the fake formula"
  grep -Fqx "managed_by=oh-my-devpod" "${marker}" ||
    fail "${component} install should create an ownership marker"
  grep -Fqx "component=${component}" "${marker}" ||
    fail "${component} marker should record the component"
  grep -Fqx "kind=brew-formula" "${marker}" ||
    fail "${component} marker should record the formula kind"
  grep -Fqx "artifact=${component}" "${marker}" ||
    fail "${component} marker should record the formula"
  grep -Fqx "brew_prefix=${resolved_brew_prefix}" "${marker}" ||
    fail "${component} marker should record the owning Homebrew prefix"

  env \
    HOME="${formula_home}" \
    PATH="/usr/bin:/bin" \
    OHMYDEVPOD_BREW_BIN="${fake_brew}" \
    OHMYDEVPOD_TEST_BREW_STATE="${formula_state}" \
    "${module}" managed

  env \
    HOME="${formula_home}" \
    PATH="/usr/bin:/bin" \
    OHMYDEVPOD_BREW_BIN="${fake_brew}" \
    OHMYDEVPOD_TEST_BREW_STATE="${formula_state}" \
    "${module}" uninstall

  [[ ! -d "${formula_state}" ]] || fail "${component} uninstall should remove the fake formula"
  [[ ! -e "${marker}" ]] || fail "${component} uninstall should remove its marker"
done

make_prefix_brew() {
  local prefix="$1" log="$2"
  mkdir -p "${prefix}/bin" "${prefix}/Cellar/yq/1.0"
  cat > "${prefix}/bin/brew" <<EOF
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "\$*" >> "${log}"
case "\${1:-}" in
  --prefix)
    printf '%s\n' "${prefix}"
    ;;
  install|upgrade)
    mkdir -p "${prefix}/Cellar/yq/1.0"
    ;;
  uses)
    ;;
  uninstall)
    rm -rf "${prefix}/Cellar/yq"
    ;;
  *)
    exit 2
    ;;
esac
EOF
  chmod +x "${prefix}/bin/brew"
}

owned_prefix="${tmp_dir}/owned-prefix"
external_prefix="${tmp_dir}/external-prefix"
owned_log="${tmp_dir}/owned-prefix.log"
external_log="${tmp_dir}/external-prefix.log"
: > "${owned_log}"
: > "${external_log}"
make_prefix_brew "${owned_prefix}" "${owned_log}"
make_prefix_brew "${external_prefix}" "${external_log}"
owned_prefix="$(cd "${owned_prefix}" && pwd -P)"
external_prefix="$(cd "${external_prefix}" && pwd -P)"

prefix_home="${tmp_dir}/prefix-home"
prefix_marker="${prefix_home}/.local/state/oh-my-devpod/managed/yq"
mkdir -p "$(dirname "${prefix_marker}")"
cat > "${prefix_marker}" <<EOF
managed_by=oh-my-devpod
component=yq
kind=brew-formula
artifact=yq
brew_prefix=${owned_prefix}
EOF

env \
  HOME="${prefix_home}" \
  PATH="/usr/bin:/bin" \
  OHMYDEVPOD_BREW_BIN="${external_prefix}/bin/brew" \
  "${repo_root}/modules/tools/yq.sh" update
grep -Fqx 'upgrade yq' "${owned_log}" ||
  fail "managed formula update should use its marker-owned Homebrew prefix"
[[ ! -s "${external_log}" ]] ||
  fail "managed formula update should not use an unrelated current Homebrew"

env \
  HOME="${prefix_home}" \
  PATH="/usr/bin:/bin" \
  OHMYDEVPOD_BREW_BIN="${external_prefix}/bin/brew" \
  "${repo_root}/modules/tools/yq.sh" uninstall
[[ ! -d "${owned_prefix}/Cellar/yq" ]] ||
  fail "managed formula uninstall should remove the owned-prefix formula"
[[ -d "${external_prefix}/Cellar/yq/1.0" ]] ||
  fail "managed formula uninstall should preserve an unrelated external formula"
[[ ! -e "${prefix_marker}" ]] ||
  fail "managed formula uninstall should remove its marker"

mkdir -p "${owned_prefix}/Cellar/yq/1.0" "$(dirname "${prefix_marker}")"
: > "${owned_log}"
: > "${external_log}"
cat > "${prefix_marker}" <<'EOF'
managed_by=oh-my-devpod
component=yq
kind=brew-formula
artifact=yq
EOF
cat > "${prefix_home}/.local/state/oh-my-devpod/managed/linuxbrew" <<EOF
managed_by=oh-my-devpod
component=linuxbrew
kind=directory
artifact=${owned_prefix}
EOF

env \
  HOME="${prefix_home}" \
  PATH="/usr/bin:/bin" \
  OHMYDEVPOD_BREW_BIN="${external_prefix}/bin/brew" \
  "${repo_root}/modules/tools/yq.sh" update
grep -Fqx 'upgrade yq' "${owned_log}" ||
  fail "legacy formula markers should infer the managed Linuxbrew prefix"
[[ ! -s "${external_log}" ]] ||
  fail "legacy marker migration should not use an unrelated current Homebrew"

symlink_prefix="${tmp_dir}/symlink-prefix"
symlink_home="${tmp_dir}/symlink-prefix-home"
mkdir -p \
  "${symlink_prefix}/bin" \
  "${symlink_prefix}/Homebrew/bin" \
  "${symlink_home}"
cat > "${symlink_prefix}/Homebrew/bin/brew" <<EOF
#!/usr/bin/env bash
set -euo pipefail
case "\${1:-}" in
  --prefix)
    printf '%s\n' "${symlink_prefix}"
    ;;
  install)
    mkdir -p "${symlink_prefix}/Cellar/yq/1.0"
    ;;
  upgrade|uses|uninstall)
    ;;
  *)
    exit 2
    ;;
esac
EOF
chmod +x "${symlink_prefix}/Homebrew/bin/brew"
ln -s ../Homebrew/bin/brew "${symlink_prefix}/bin/brew"

env \
  HOME="${symlink_home}" \
  PATH="/usr/bin:/bin" \
  OHMYDEVPOD_BREW_BIN="${symlink_prefix}/bin/brew" \
  "${repo_root}/modules/tools/yq.sh" install
grep -Fqx \
  "brew_prefix=$(cd "${symlink_prefix}" && pwd -P)" \
  "${symlink_home}/.local/state/oh-my-devpod/managed/yq" ||
  fail "formula marker should record brew --prefix rather than the resolved brew script directory"

hijack_prefix="${tmp_dir}/hijack-prefix"
hijack_home="${tmp_dir}/hijack-home"
hijack_marker="${hijack_home}/.local/state/oh-my-devpod/managed/yq"
mkdir -p \
  "${hijack_prefix}/bin" \
  "${hijack_prefix}/Cellar/yq/1.0" \
  "$(dirname "${hijack_marker}")"
ln -s "${external_prefix}/bin/brew" "${hijack_prefix}/bin/brew"
hijack_prefix="$(cd "${hijack_prefix}" && pwd -P)"
cat > "${hijack_marker}" <<EOF
managed_by=oh-my-devpod
component=yq
kind=brew-formula
artifact=yq
brew_prefix=${hijack_prefix}
EOF
: > "${external_log}"
if env \
  HOME="${hijack_home}" \
  PATH="/usr/bin:/bin" \
  OHMYDEVPOD_BREW_BIN="${external_prefix}/bin/brew" \
  "${repo_root}/modules/tools/yq.sh" update >/dev/null 2>&1; then
  fail "managed formula update should reject a brew symlink escaping its owned prefix"
fi
[[ ! -s "${external_log}" ]] ||
  fail "rejected brew symlink should not execute the external Homebrew command"
[[ -d "${external_prefix}/Cellar/yq/1.0" ]] ||
  fail "rejected brew symlink should preserve the external formula"
