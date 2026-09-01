#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
workflow="${repo_root}/.github/workflows/release-omd.yml"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_contains() {
  local pattern="$1"
  rg -q --fixed-strings -- "${pattern}" "${workflow}" || fail "workflow should contain: ${pattern}"
}

assert_not_contains() {
  local pattern="$1"
  if rg -q --fixed-strings -- "${pattern}" "${workflow}"; then
    fail "workflow should not contain: ${pattern}"
  fi
}

[[ -f "${workflow}" ]] || fail "missing release workflow: ${workflow}"
assert_contains 'cargo build --release -p omd'
assert_contains 'omd-x86_64-unknown-linux-gnu.tar.gz'
assert_contains 'softprops/action-gh-release'
assert_contains 'tar -czf'
assert_contains 'sha256sum'
assert_contains 'id-token: write'
assert_contains 'actions/setup-node@v4'
assert_contains 'npm@11.5.1'
assert_contains 'bash build/package-npm.sh'
assert_contains 'npm publish'
assert_contains '--provenance'
assert_contains '--access public'
assert_contains '--tag "${npm_tag}"'
assert_contains 'npm/package.json'
assert_contains 'release tag {actual} does not match VERSION {version}'
assert_contains 'publish-npm:'
assert_contains 'npm view "oh-my-devpod@${version}" version'
assert_contains 'is already published; skipping.'
assert_not_contains 'docker/build-push-action'
assert_not_contains 'ghcr.io'

package_script="${tmp_dir}/package.sh"
awk '
  /- name: Package omd/ { in_step = 1 }
  in_step && /run: \|/ { in_script = 1; next }
  in_script && /^      - name:/ { exit }
  in_script {
    sub(/^          /, "")
    print
  }
' "${workflow}" > "${package_script}"
[[ -s "${package_script}" ]] || fail "could not extract Package omd run script"

worktree="${tmp_dir}/worktree"
mkdir -p "${worktree}/target/release"
cp -R \
  "${repo_root}/components.toml" \
  "${repo_root}/install" \
  "${repo_root}/modules" \
  "${repo_root}/build" \
  "${repo_root}/config" \
  "${repo_root}/VERSION" \
  "${repo_root}/versions.env" \
  "${worktree}/"
mkdir -p \
  "${worktree}/vendor/releases/antidote" \
  "${worktree}/vendor/nvim" \
  "${worktree}/vendor/zsh"
printf 'vendor fixture\n' > "${worktree}/vendor/marker"
printf '#!/usr/bin/env bash\nexit 0\n' > "${worktree}/target/release/omd"
chmod +x "${worktree}/target/release/omd"

(cd "${worktree}" && bash "${package_script}")

archive="${worktree}/dist/omd-x86_64-unknown-linux-gnu.tar.gz"
[[ -f "${archive}" ]] || fail "package step did not create release archive"
archive_listing="${tmp_dir}/archive.list"
tar -tzf "${archive}" > "${archive_listing}"

for expected in \
  oh-my-devpod/bin/omd \
  oh-my-devpod/components.toml \
  oh-my-devpod/install/bootstrap.sh \
  oh-my-devpod/install/update.sh \
  oh-my-devpod/modules/ \
  oh-my-devpod/modules/lib/source-config.sh \
  oh-my-devpod/build/ \
  oh-my-devpod/build/install-gitee-cli.sh \
  oh-my-devpod/config/ \
  oh-my-devpod/vendor/ \
  oh-my-devpod/VERSION \
  oh-my-devpod/versions.env; do
  grep -Fq "${expected}" "${archive_listing}" \
    || fail "release archive should contain: ${expected}"
done

checksum="${archive}.sha256"
[[ -f "${checksum}" ]] || fail "package step did not create checksum"
(cd "$(dirname "${archive}")" && sha256sum -c "$(basename "${checksum}")" >/dev/null)
