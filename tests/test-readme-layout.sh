#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
english="${repo_root}/README.md"
chinese="${repo_root}/Readme.osc.md"
compatibility="${repo_root}/README_EN.md"
hero="${repo_root}/docs/assets/omd-hero.svg"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_contains() {
  local path="$1" text="$2"
  grep -Fq "${text}" "${path}" || fail "expected '${text}' in ${path}"
}

[[ -f "${english}" ]] || fail "GitHub default README.md is missing"
[[ -f "${chinese}" ]] || fail "Gitee default Readme.osc.md is missing"
[[ -f "${compatibility}" ]] || fail "README_EN.md compatibility file is missing"
[[ -f "${hero}" ]] || fail "README hero asset is missing"

assert_contains "${english}" 'English'
assert_contains "${english}" './Readme.osc.md'
assert_contains "${english}" 'Micromamba'
assert_contains "${english}" 'Gitee CLI'
assert_contains "${english}" 'GitHub CLI'
assert_contains "${english}" '**yq**'
assert_contains "${english}" 'directory jumping'
assert_contains "${english}" 'omd --update --github'
assert_contains "${english}" 'npm install --global oh-my-devpod'
assert_contains "${english}" 'npm update --global oh-my-devpod'
assert_contains "${english}" 'omd --source gitee'
assert_contains "${english}" 'omd --source github'
assert_contains "${english}" 'already installed and owned by OMD'
assert_contains "${english}" './docs/assets/omd-hero.svg'

assert_contains "${chinese}" '中文'
assert_contains "${chinese}" './README.md'
assert_contains "${chinese}" 'Micromamba'
assert_contains "${chinese}" 'Gitee CLI'
assert_contains "${chinese}" 'GitHub CLI'
assert_contains "${chinese}" '**yq**'
assert_contains "${chinese}" '目录跳转'
assert_contains "${chinese}" 'omd --update --gitee'
assert_contains "${chinese}" 'npm install --global oh-my-devpod'
assert_contains "${chinese}" 'npm update --global oh-my-devpod'
assert_contains "${chinese}" 'omd --source gitee'
assert_contains "${chinese}" 'omd --source github'
assert_contains "${chinese}" '已经安装且由 OMD 管理'
assert_contains "${chinese}" './docs/assets/omd-hero.svg'

assert_contains "${compatibility}" './README.md'

echo "README layout tests passed"
