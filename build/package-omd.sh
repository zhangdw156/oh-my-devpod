#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
binary="${1:-${repo_root}/target/release/omd}"
dist_dir="${2:-${repo_root}/dist}"
target="${3:-x86_64-unknown-linux-gnu}"
archive_name="omd-${target}.tar.gz"
staging_dir="$(mktemp -d)"
bundle_root="${staging_dir}/oh-my-devpod"

cleanup() {
  rm -rf "${staging_dir}"
}
trap cleanup EXIT

[[ "${target}" == "x86_64-unknown-linux-gnu" ]] || {
  printf 'Unsupported release target: %s\n' "${target}" >&2
  exit 1
}
[[ -x "${binary}" ]] || {
  printf 'Missing executable omd binary: %s\n' "${binary}" >&2
  exit 1
}

for required in components.toml modules build config vendor VERSION versions.env; do
  [[ -e "${repo_root}/${required}" ]] || {
    printf 'Missing runtime bundle input: %s\n' "${required}" >&2
    exit 1
  }
done

python3 - "${repo_root}" <<'PY'
import pathlib
import sys
import tomllib

root = pathlib.Path(sys.argv[1]).resolve()
with (root / "components.toml").open("rb") as handle:
    manifest = tomllib.load(handle)

for component in manifest["component"]:
    module = (root / component["module"]).resolve()
    try:
        module.relative_to(root / "modules")
    except ValueError:
        raise SystemExit(
            f"component {component['id']} module escapes modules/: {module}"
        )
    if not module.is_file():
        raise SystemExit(
            f"component {component['id']} module is missing: {module}"
        )
PY

mkdir -p "${bundle_root}/bin" "${dist_dir}"
install -m 0755 "${binary}" "${bundle_root}/bin/omd"
cp "${repo_root}/components.toml" "${bundle_root}/components.toml"
cp "${repo_root}/VERSION" "${bundle_root}/VERSION"
cp "${repo_root}/versions.env" "${bundle_root}/versions.env"
cp -R "${repo_root}/modules" "${bundle_root}/modules"
cp -R "${repo_root}/build" "${bundle_root}/build"
cp -R "${repo_root}/config" "${bundle_root}/config"
cp -R "${repo_root}/vendor" "${bundle_root}/vendor"

# Release bundles are target-specific. Exclude other architecture payloads so
# the archive remains small enough for both GitHub and Gitee release hosting.
find "${bundle_root}/vendor/releases" -type f \
  \( -name '*aarch64*' -o -name '*arm64*' \) -delete

tar -czf "${dist_dir}/${archive_name}" -C "${staging_dir}" oh-my-devpod
(
  cd "${dist_dir}"
  sha256sum "${archive_name}" > "${archive_name}.sha256"
)

printf '%s\n' "${dist_dir}/${archive_name}"
printf '%s\n' "${dist_dir}/${archive_name}.sha256"
