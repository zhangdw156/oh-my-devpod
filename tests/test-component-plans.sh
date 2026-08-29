#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

if ! command -v cargo >/dev/null 2>&1; then
  echo "SKIP: cargo is required for component plan acceptance tests"
  exit 0
fi

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_contains() {
  local haystack="$1" needle="$2"
  grep -Eiq "(^|[^[:alnum:]_-])${needle}([^[:alnum:]_-]|$)" <<<"${haystack}" \
    || fail "expected output to mention component '${needle}': ${haystack}"
}

component_position() {
  local output="$1" component="$2"
  grep -Eibo -m1 "(^|[^[:alnum:]_-])${component}([^[:alnum:]_-]|$)" <<<"${output}" \
    | cut -d: -f1
}

assert_before() {
  local output="$1" first="$2" second="$3" first_position second_position
  first_position="$(component_position "${output}" "${first}")"
  second_position="$(component_position "${output}" "${second}")"
  [[ -n "${first_position}" && -n "${second_position}" ]] \
    || fail "could not find '${first}' and '${second}' in plan: ${output}"
  (( first_position < second_position )) \
    || fail "expected '${first}' before '${second}' in plan: ${output}"
}

run_expect_failure() {
  local description="$1"
  shift
  local output status
  set +e
  output="$("$@" 2>&1)"
  status=$?
  set -e
  (( status != 0 )) || fail "expected failure: ${description}"
  printf '%s\n' "${output}"
}

(cd "${repo_root}" && cargo build --quiet -p omd)
omd="${repo_root}/target/debug/omd"

install_plan="$("${omd}" --plan install lazyvim)"
assert_contains "${install_plan}" git
assert_contains "${install_plan}" neovim
assert_contains "${install_plan}" lazyvim
assert_before "${install_plan}" git lazyvim
assert_before "${install_plan}" neovim lazyvim

unknown_output="$(run_expect_failure "unknown component" "${omd}" --plan install no-such-component)"
grep -Eiq 'unknown|not found' <<<"${unknown_output}" \
  || fail "unknown component error should be actionable: ${unknown_output}"
assert_contains "${unknown_output}" no-such-component

fixture="${tmp_dir}/bundle"
mkdir -p "${fixture}/modules/lib"
cp "${repo_root}/components.toml" "${fixture}/components.toml"
cp "${repo_root}/VERSION" "${fixture}/VERSION"
printf '#!/usr/bin/env bash\n' > "${fixture}/modules/lib/common.sh"
chmod +x "${fixture}/modules/lib/common.sh"

python3 - "${fixture}" <<'PY'
import pathlib
import shlex
import sys
import tomllib

root = pathlib.Path(sys.argv[1])
with (root / "components.toml").open("rb") as handle:
    components = tomllib.load(handle)["component"]

template = """#!/usr/bin/env bash
set -euo pipefail
component_id={component_id}
case "${{1:-}}" in
  status)
    [[ "${{OHMYDEVPOD_TEST_MISSING:-}}" != "${{component_id}}" ]]
    ;;
  managed)
    [[ "${{OHMYDEVPOD_TEST_UNMANAGED:-}}" != "${{component_id}}" ]]
    ;;
  install|update|uninstall) exit 0 ;;
  *) exit 2 ;;
esac
"""

for component in components:
    path = root / component["module"]
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        template.format(component_id=shlex.quote(component["id"])),
        encoding="utf-8",
    )
    path.chmod(0o755)
PY

uninstall_plan="$(
  OHMYDEVPOD_BUNDLE_ROOT="${fixture}" \
    "${omd}" --plan uninstall lazyvim neovim git
)"
assert_before "${uninstall_plan}" lazyvim neovim
assert_before "${uninstall_plan}" lazyvim git

reverse_output="$(
  run_expect_failure "installed reverse dependency" \
    env OHMYDEVPOD_BUNDLE_ROOT="${fixture}" \
    "${omd}" --plan-current uninstall neovim
)"
assert_contains "${reverse_output}" neovim
assert_contains "${reverse_output}" lazyvim

unmanaged_output="$(
  run_expect_failure "unmanaged component removal" \
    env OHMYDEVPOD_BUNDLE_ROOT="${fixture}" OHMYDEVPOD_TEST_UNMANAGED=lazyvim \
    "${omd}" --plan-current uninstall lazyvim
)"
assert_contains "${unmanaged_output}" lazyvim
grep -Eiq 'unmanaged|external|not managed' <<<"${unmanaged_output}" \
  || fail "unmanaged removal error should explain ownership: ${unmanaged_output}"

broken_plan="$(
  OHMYDEVPOD_BUNDLE_ROOT="${fixture}" \
  OHMYDEVPOD_TEST_MISSING=lazyvim \
    "${omd}" --plan-current install lazyvim
)"
grep -Eq '^update[[:space:]]+lazyvim' <<<"${broken_plan}" \
  || fail "managed but missing LazyVim should be repaired with update: ${broken_plan}"

cycle_fixture="${tmp_dir}/cycle-bundle"
cp -R "${fixture}" "${cycle_fixture}"
cat >> "${cycle_fixture}/components.toml" <<'TOML'

[[component]]
id = "cycle-a"
name = "Cycle A"
description = "Cycle fixture A"
category = "terminal"
module = "modules/cycle-a.sh"
requires = ["cycle-b"]
install_requires = []
uninstall = true

[[component]]
id = "cycle-b"
name = "Cycle B"
description = "Cycle fixture B"
category = "terminal"
module = "modules/cycle-b.sh"
requires = ["cycle-a"]
install_requires = []
uninstall = true
TOML

cycle_output="$(
  run_expect_failure "dependency cycle" \
    env OHMYDEVPOD_BUNDLE_ROOT="${cycle_fixture}" \
    "${omd}" --plan install cycle-a
)"
grep -Eiq 'cycle|cyclic' <<<"${cycle_output}" \
  || fail "dependency cycle error should be actionable: ${cycle_output}"
