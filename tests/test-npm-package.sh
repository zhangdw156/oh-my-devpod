#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

for command in node npm tar; do
  command -v "${command}" >/dev/null 2>&1 || fail "${command} is required"
done

node - "${repo_root}" <<'NODE'
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const root = process.argv[2];
const manifest = require(path.join(root, "npm/package.json"));
const version = fs.readFileSync(path.join(root, "VERSION"), "utf8").trim();

assert.equal(manifest.name, "oh-my-devpod");
assert.equal(manifest.version, "0.15.4");
assert.equal(manifest.version, version);
assert.equal(manifest.bin.omd, "bin/omd");
assert.equal(manifest.engines.node, ">=18");
assert.deepEqual(manifest.os, ["linux"]);
assert.deepEqual(manifest.cpu, ["x64"]);
assert.deepEqual(manifest.libc, ["glibc"]);
assert.equal(manifest.scripts.postinstall, "node lib/postinstall.js");
assert.equal(manifest.repository.url, "git+https://github.com/zhangdw156/oh-my-devpod.git");
assert.equal(manifest.publishConfig.access, "public");
assert.equal(manifest.publishConfig.provenance, true);
NODE

node - "${repo_root}" "${tmp_dir}" <<'NODE'
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const root = process.argv[2];
const tmp = process.argv[3];
const platform = require(path.join(root, "npm/lib/platform"));
const source = require(path.join(root, "npm/lib/source"));
const postinstall = require(path.join(root, "npm/lib/postinstall"));

assert.deepEqual(
  platform.parseOsRelease('ID=ubuntu\nVERSION_ID="24.04"\nNAME="Ubuntu Linux"\n'),
  { ID: "ubuntu", VERSION_ID: "24.04", NAME: "Ubuntu Linux" },
);

const supported = {
  platform: "linux",
  arch: "x64",
  glibcVersion: "2.39",
  osRelease: { ID: "ubuntu", VERSION_ID: "24.04" },
};
platform.validatePlatform(supported);
assert.throws(
  () => platform.validatePlatform({ ...supported, platform: "darwin" }),
  /requires Ubuntu 24\.04 on Linux x64\/glibc/,
);
assert.throws(
  () => platform.validatePlatform({ ...supported, arch: "arm64" }),
  /requires Linux x64/,
);
assert.throws(
  () => platform.validatePlatform({ ...supported, glibcVersion: null }),
  /glibc \(musl is not supported\)/,
);
assert.throws(
  () =>
    platform.validatePlatform({
      ...supported,
      osRelease: { ID: "ubuntu", VERSION_ID: "22.04" },
    }),
  /requires Ubuntu 24\.04/,
);

assert.equal(source.selectSource(undefined), "github");
assert.equal(source.selectSource("github"), "github");
assert.equal(source.selectSource("gitee"), "gitee");
assert.equal(source.selectSource(undefined, "gitee"), "gitee");
assert.throws(() => source.selectSource("mirror"), /expected github or gitee/);
assert.equal(
  source.sourceStatePath(
    { OHMYDEVPOD_CONFIG_DIR: "/tmp/custom-omd-config" },
    "/home/test-user",
  ),
  "/tmp/custom-omd-config/npm-source",
);

for (const [requested, expected] of [
  [undefined, "github"],
  ["github", "github"],
  ["gitee", "gitee"],
]) {
  const packageRoot = fs.mkdtempSync(path.join(tmp, "postinstall-"));
  const stateFile = path.join(packageRoot, "state", "npm-source");
  const env = requested === undefined ? {} : { OHMYDEVPOD_SOURCE: requested };
  assert.equal(
    postinstall.main({ env, packageRoot, platformInfo: supported, stateFile }),
    expected,
  );
  assert.equal(
    fs.readFileSync(path.join(packageRoot, ".npm-source"), "utf8"),
    `${expected}\n`,
  );
  assert.equal(fs.readFileSync(stateFile, "utf8"), `${expected}\n`);
}

const invalidRoot = fs.mkdtempSync(path.join(tmp, "postinstall-invalid-"));
assert.throws(
  () =>
    postinstall.main({
      env: { OHMYDEVPOD_SOURCE: "invalid" },
      packageRoot: invalidRoot,
      platformInfo: supported,
      stateFile: path.join(invalidRoot, "state", "npm-source"),
    }),
  /invalid OHMYDEVPOD_SOURCE/,
);
assert.equal(fs.existsSync(path.join(invalidRoot, ".npm-source")), false);

const preservedRoot = fs.mkdtempSync(path.join(tmp, "postinstall-preserved-"));
const preservedState = path.join(preservedRoot, "state", "npm-source");
fs.mkdirSync(path.dirname(preservedState), { recursive: true });
fs.writeFileSync(preservedState, "gitee\n");
assert.equal(
  postinstall.main({
    env: {},
    packageRoot: preservedRoot,
    platformInfo: supported,
    stateFile: preservedState,
  }),
  "gitee",
);
assert.equal(
  fs.readFileSync(path.join(preservedRoot, ".npm-source"), "utf8"),
  "gitee\n",
);
NODE

launcher_fixture="${tmp_dir}/launcher-package"
mkdir -p "${launcher_fixture}/bin" "${launcher_fixture}/runtime/bin"
cp "${repo_root}/npm/bin/omd" "${launcher_fixture}/bin/omd"
chmod +x "${launcher_fixture}/bin/omd"
printf 'github\n' > "${launcher_fixture}/.npm-source"
cat > "${launcher_fixture}/runtime/bin/omd" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
{
  printf 'bundle=%s\n' "${OHMYDEVPOD_BUNDLE_ROOT:-}"
  printf 'channel=%s\n' "${OHMYDEVPOD_INSTALL_CHANNEL:-}"
  printf 'source=%s\n' "${OHMYDEVPOD_NPM_SOURCE:-}"
  printf 'bin_dir=%s\n' "${OHMYDEVPOD_BIN_DIR:-}"
  printf 'argc=%s\n' "$#"
  index=0
  for argument in "$@"; do
    printf 'arg%s=%s\n' "${index}" "${argument}"
    index=$((index + 1))
  done
} > "${OMD_TEST_OUTPUT}"
exit "${OMD_TEST_EXIT:-0}"
MOCK
chmod +x "${launcher_fixture}/runtime/bin/omd"

launcher_output="${tmp_dir}/launcher.out"
launcher_config="${tmp_dir}/launcher-config"
mkdir -p "${launcher_config}/oh-my-devpod"
printf 'gitee\n' > "${launcher_config}/oh-my-devpod/npm-source"
set +e
XDG_CONFIG_HOME="${launcher_config}" \
  OMD_TEST_OUTPUT="${launcher_output}" \
  OMD_TEST_EXIT=37 \
  "${launcher_fixture}/bin/omd" --plan "two words" '*.txt'
launcher_status=$?
set -e
[[ "${launcher_status}" == "37" ]] || fail "launcher should propagate exit status"
grep -Fqx "bundle=${launcher_fixture}/runtime" "${launcher_output}" ||
  fail "launcher should set OHMYDEVPOD_BUNDLE_ROOT"
grep -Fqx 'channel=npm' "${launcher_output}" ||
  fail "launcher should set OHMYDEVPOD_INSTALL_CHANNEL"
grep -Fqx 'source=gitee' "${launcher_output}" ||
  fail "launcher should set OHMYDEVPOD_NPM_SOURCE"
grep -Fqx "bin_dir=${HOME}/.local/bin" "${launcher_output}" ||
  fail "launcher should keep component binaries outside the npm package"
grep -Fqx 'argc=3' "${launcher_output}" ||
  fail "launcher should preserve argument count"
grep -Fqx 'arg0=--plan' "${launcher_output}" ||
  fail "launcher should preserve first argument"
grep -Fqx 'arg1=two words' "${launcher_output}" ||
  fail "launcher should preserve whitespace in arguments"
grep -Fqx 'arg2=*.txt' "${launcher_output}" ||
  fail "launcher should not expand arguments"

empty_launcher_config="${tmp_dir}/empty-launcher-config"
mkdir -p "${empty_launcher_config}"
XDG_CONFIG_HOME="${empty_launcher_config}" \
  OMD_TEST_OUTPUT="${launcher_output}" \
  "${launcher_fixture}/bin/omd" --version
grep -Fqx 'source=github' "${launcher_output}" ||
  fail "launcher should fall back to the package source when user state is absent"

XDG_CONFIG_HOME="${launcher_config}" \
  OMD_TEST_OUTPUT="${launcher_output}" \
  "${launcher_fixture}/bin/omd" --update
grep -Fqx 'arg0=--update' "${launcher_output}" ||
  fail "launcher should pass update requests to the bundled omd binary"

mkdir -p "${tmp_dir}/global-bin"
ln -s "${launcher_fixture}/bin/omd" "${tmp_dir}/global-bin/omd"
XDG_CONFIG_HOME="${launcher_config}" \
  OMD_TEST_OUTPUT="${launcher_output}" \
  "${tmp_dir}/global-bin/omd" --version
grep -Fqx "bundle=${launcher_fixture}/runtime" "${launcher_output}" ||
  fail "launcher should resolve an npm-style global symlink"
grep -Fqx 'arg0=--version' "${launcher_output}" ||
  fail "symlinked launcher should preserve arguments"

release_root="${tmp_dir}/release/oh-my-devpod"
mkdir -p \
  "${release_root}/bin" \
  "${release_root}/install" \
  "${release_root}/modules/lib" \
  "${release_root}/build" \
  "${release_root}/config" \
  "${release_root}/vendor"
cat > "${release_root}/bin/omd" <<'MOCK'
#!/usr/bin/env bash
if [[ -n "${OMD_TEST_OUTPUT:-}" ]]; then
  {
    printf 'bundle=%s\n' "${OHMYDEVPOD_BUNDLE_ROOT:-}"
    printf 'channel=%s\n' "${OHMYDEVPOD_INSTALL_CHANNEL:-}"
    printf 'source=%s\n' "${OHMYDEVPOD_NPM_SOURCE:-}"
    printf 'arg0=%s\n' "${1:-}"
  } > "${OMD_TEST_OUTPUT}"
fi
exit 0
MOCK
chmod +x "${release_root}/bin/omd"
printf '0.15.4\n' > "${release_root}/VERSION"
printf 'fixture components\n' > "${release_root}/components.toml"
printf 'fixture versions\n' > "${release_root}/versions.env"
printf 'fixture bootstrap\n' > "${release_root}/install/bootstrap.sh"
printf 'fixture update\n' > "${release_root}/install/update.sh"
printf 'fixture module\n' > "${release_root}/modules/lib/common.sh"
printf 'fixture source config\n' > "${release_root}/modules/lib/source-config.sh"
printf 'fixture shared brew\n' > "${release_root}/modules/lib/shared-linuxbrew.sh"
printf 'fixture brew gateway\n' > "${release_root}/build/omd-brew-gateway.sh"
printf 'fixture brew provisioner\n' > "${release_root}/build/omd-brew-provisioner.sh"
printf 'fixture build\n' > "${release_root}/build/helper.sh"
printf 'fixture config\n' > "${release_root}/config/example"
printf 'fixture hidden config\n' > "${release_root}/config/.hidden-example"
printf 'fixture vendor\n' > "${release_root}/vendor/example"
printf 'complete bundle marker\n' > "${release_root}/extra-release-file"

release_archive="${tmp_dir}/omd-x86_64-unknown-linux-gnu.tar.gz"
tar -czf "${release_archive}" -C "${tmp_dir}/release" oh-my-devpod
npm_dist="${tmp_dir}/dist"
package_path="$("${repo_root}/build/package-npm.sh" "${release_archive}" "${npm_dist}")"
[[ -f "${package_path}" ]] || fail "package script did not create npm archive"
[[ "$(basename "${package_path}")" == "oh-my-devpod-0.15.4.tgz" ]] ||
  fail "unexpected npm archive name: ${package_path}"

packed_listing="${tmp_dir}/packed.list"
tar -tzf "${package_path}" > "${packed_listing}"
for expected in \
  package/package.json \
  package/LICENSE \
  package/bin/omd \
  package/lib/postinstall.js \
  package/lib/platform.js \
  package/lib/source.js \
  package/runtime/bin/omd \
  package/runtime/components.toml \
  package/runtime/install/bootstrap.sh \
  package/runtime/install/update.sh \
  package/runtime/modules/lib/common.sh \
  package/runtime/modules/lib/source-config.sh \
  package/runtime/modules/lib/shared-linuxbrew.sh \
  package/runtime/build/omd-brew-gateway.sh \
  package/runtime/build/omd-brew-provisioner.sh \
  package/runtime/build/helper.sh \
  package/runtime/config/example \
  package/runtime/config/.hidden-example \
  package/runtime/vendor/example \
  package/runtime/VERSION \
  package/runtime/versions.env \
  package/runtime/extra-release-file; do
  grep -Fqx "${expected}" "${packed_listing}" ||
    fail "packed npm archive should contain: ${expected}"
done

unpacked="${tmp_dir}/unpacked"
mkdir -p "${unpacked}"
tar -xzf "${package_path}" -C "${unpacked}"
[[ -x "${unpacked}/package/bin/omd" ]] ||
  fail "packed launcher should be executable"
[[ -x "${unpacked}/package/runtime/bin/omd" ]] ||
  fail "packed runtime binary should be executable"
[[ ! -e "${unpacked}/package/.npm-source" ]] ||
  fail "source selection should be created by postinstall, not baked into package"

if [[ "$(uname -s)" == "Linux" ]] &&
  grep -Eq '^ID="?ubuntu"?$' /etc/os-release &&
  grep -Eq '^VERSION_ID="?24\.04"?$' /etc/os-release; then
  npm_prefix="${tmp_dir}/npm-prefix"
  npm_config_home="${tmp_dir}/npm-config"
  install_output="${tmp_dir}/npm-install.out"
  XDG_CONFIG_HOME="${npm_config_home}" OHMYDEVPOD_SOURCE=gitee npm install \
    --global \
    --prefix "${npm_prefix}" \
    "${package_path}" >"${install_output}"
  [[ "$(cat "${npm_config_home}/oh-my-devpod/npm-source")" == "gitee" ]] ||
    fail "npm install should persist the selected source outside node_modules"
  installed_output="${tmp_dir}/npm-installed-launcher.out"
  OMD_TEST_OUTPUT="${installed_output}" "${npm_prefix}/bin/omd" --version
  grep -Fqx 'channel=npm' "${installed_output}" ||
    fail "npm-installed launcher should identify the npm channel"
  grep -Fqx 'source=gitee' "${installed_output}" ||
    fail "npm install should persist the requested gitee source"
  grep -Fqx 'arg0=--version' "${installed_output}" ||
    fail "npm-installed launcher should execute the bundled runtime"
fi

printf '0.14.1\n' > "${release_root}/VERSION"
tar -czf "${tmp_dir}/wrong-version.tar.gz" -C "${tmp_dir}/release" oh-my-devpod
if "${repo_root}/build/package-npm.sh" \
  "${tmp_dir}/wrong-version.tar.gz" \
  "${tmp_dir}/wrong-version-dist" >"${tmp_dir}/wrong-version.out" 2>&1; then
  fail "package script should reject a mismatched bundle version"
fi
grep -Fq 'bundle version (0.14.1) does not match npm package version (0.15.4)' \
  "${tmp_dir}/wrong-version.out" ||
  fail "version mismatch should produce a clear error"

printf '0.15.4\n' > "${release_root}/VERSION"
rm "${release_root}/install/update.sh"
tar -czf "${tmp_dir}/incomplete.tar.gz" -C "${tmp_dir}/release" oh-my-devpod
if "${repo_root}/build/package-npm.sh" \
  "${tmp_dir}/incomplete.tar.gz" \
  "${tmp_dir}/incomplete-dist" >"${tmp_dir}/incomplete.out" 2>&1; then
  fail "package script should reject an incomplete release bundle"
fi
grep -Fq 'release bundle is missing: install/update.sh' \
  "${tmp_dir}/incomplete.out" ||
  fail "incomplete bundle should produce a clear error"

if rg -n '\b(curl|wget)\b' "${repo_root}/build/package-npm.sh" >/dev/null; then
  fail "npm packaging must not download artifacts"
fi
