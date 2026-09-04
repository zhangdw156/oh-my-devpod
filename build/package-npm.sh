#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
archive="${1:-}"
dist_dir="${2:-${repo_root}/dist}"
staging_dir="$(mktemp -d)"
package_dir="${staging_dir}/package"
archive_dir="${staging_dir}/archive"

cleanup() {
  rm -rf "${staging_dir}"
}
trap cleanup EXIT

fail() {
  printf 'package-npm: %s\n' "$*" >&2
  exit 1
}

[[ -n "${archive}" ]] || fail "usage: $0 <omd-release-archive.tar.gz> [dist-dir]"
[[ -f "${archive}" ]] || fail "release archive not found: ${archive}"
command -v node >/dev/null 2>&1 || fail "node is required"
command -v npm >/dev/null 2>&1 || fail "npm is required"
command -v tar >/dev/null 2>&1 || fail "tar is required"

repo_version="$(tr -d '[:space:]' < "${repo_root}/VERSION")"
package_version="$(
  node -e '
    const manifest = require(process.argv[1]);
    process.stdout.write(manifest.version);
  ' "${repo_root}/npm/package.json"
)"
[[ "${repo_version}" == "${package_version}" ]] ||
  fail "VERSION (${repo_version}) does not match npm package version (${package_version})"

archive_listing="${staging_dir}/archive.list"
tar -tzf "${archive}" > "${archive_listing}" ||
  fail "could not read release archive: ${archive}"
[[ -s "${archive_listing}" ]] || fail "release archive is empty"
if grep -Ev '^oh-my-devpod(/|$)' "${archive_listing}" >/dev/null; then
  fail "release archive must contain only the oh-my-devpod/ bundle"
fi
if grep -E '(^|/)\.\.(/|$)' "${archive_listing}" >/dev/null; then
  fail "release archive contains an unsafe path"
fi

mkdir -p "${archive_dir}" "${package_dir}" "${dist_dir}"
tar -xzf "${archive}" -C "${archive_dir}"
bundle_root="${archive_dir}/oh-my-devpod"

for required in \
  bin/omd \
  components.toml \
  install/bootstrap.sh \
  install/update.sh \
  modules/lib/shared-linuxbrew.sh \
  build/omd-brew-gateway.sh \
  build/omd-brew-provisioner.sh \
  modules/lib/source-config.sh \
  modules \
  build \
  config \
  vendor \
  VERSION \
  versions.env; do
  [[ -e "${bundle_root}/${required}" ]] ||
    fail "release bundle is missing: ${required}"
done
[[ -x "${bundle_root}/bin/omd" ]] ||
  fail "release bundle binary is not executable: bin/omd"

bundle_version="$(tr -d '[:space:]' < "${bundle_root}/VERSION")"
[[ "${bundle_version}" == "${package_version}" ]] ||
  fail "bundle version (${bundle_version}) does not match npm package version (${package_version})"

cp -R "${repo_root}/npm/." "${package_dir}/"
cp "${repo_root}/LICENSE" "${package_dir}/LICENSE"
cp -R "${bundle_root}" "${package_dir}/runtime"
chmod 0755 "${package_dir}/bin/omd" "${package_dir}/lib/postinstall.js"

pack_output="$(
  npm pack "${package_dir}" \
    --ignore-scripts \
    --silent \
    --pack-destination "${dist_dir}"
)"
package_name="$(printf '%s\n' "${pack_output}" | tail -n 1)"
[[ -n "${package_name}" && -f "${dist_dir}/${package_name}" ]] ||
  fail "npm pack did not create the expected archive"

printf '%s\n' "${dist_dir}/${package_name}"
