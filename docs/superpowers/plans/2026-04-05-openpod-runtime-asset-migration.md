# Openpod Runtime Asset Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move the remaining OpenCode-specific vendored assets from the shared repository root into `runtime/openpod/` without breaking the `openpod`, `claudepod`, and `codexpod` flavors.

**Architecture:** Keep `vendor/` as the shared base-asset root and make `runtime/openpod/vendor/opencode/` the only source of truth for OpenCode plugin packages and global skills. `Dockerfile.openpod`, the compatibility `Dockerfile`, bootstrap wiring, and `build/update-vendor-assets.sh` all shift to that runtime-owned source, while Claude and Codex continue to sync their `superpowers` skills from the new OpenCode runtime path.

**Tech Stack:** Bash, Dockerfiles, docker compose, shell smoke tests, vendored asset snapshots, JSON metadata

---

### Task 1: Add A Failing Layout Regression Test

**Files:**
- Create: `tests/test-openpod-runtime-assets.sh`
- Modify: `tests/run.sh`

- [ ] **Step 1: Add a failing runtime-asset boundary test**

```bash
#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

[[ ! -d "${repo_root}/vendor/opencode" ]] || fail "shared vendor/opencode should not exist"
[[ -d "${repo_root}/runtime/openpod/vendor/opencode/packages/superpowers" ]] || fail "missing openpod vendored superpowers package"
[[ -d "${repo_root}/runtime/openpod/vendor/opencode/skills" ]] || fail "missing openpod vendored global skills directory"

rg -q 'runtime/openpod/vendor/opencode/packages/superpowers/skills' "${repo_root}/build/update-vendor-assets.sh" \
  || fail "update-vendor-assets should sync superpowers skills from runtime/openpod"
```

- [ ] **Step 2: Run the new test and verify RED**

Run: `bash tests/test-openpod-runtime-assets.sh`
Expected: FAIL because `vendor/opencode/` still exists at the shared root and `runtime/openpod/vendor/opencode/...` does not exist yet

- [ ] **Step 3: Register the regression test**

```bash
#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

bash "${repo_root}/tests/test-install-neovim.sh"
bash "${repo_root}/tests/test-install-python-dev-tools.sh"
bash "${repo_root}/tests/test-install-lazyvim.sh"
bash "${repo_root}/tests/test-neovim-lazyvim-wiring.sh"
bash "${repo_root}/tests/test-compose-flavors.sh"
bash "${repo_root}/tests/test-bootstrap-flavors.sh"
bash "${repo_root}/tests/test-openpod-runtime-assets.sh"
```

- [ ] **Step 4: Commit**

```bash
git add tests/run.sh tests/test-openpod-runtime-assets.sh
git commit -m "test: add openpod runtime asset boundary coverage"
```

### Task 2: Move OpenCode Assets Into `runtime/openpod/`

**Files:**
- Create: `runtime/openpod/vendor/opencode/skills/.gitkeep`
- Create: `runtime/openpod/vendor/opencode/packages/superpowers/`
- Modify: `Dockerfile`
- Modify: `Dockerfile.openpod`
- Modify: `install/bootstrap.sh`
- Modify: `runtime/openpod/install-harness.sh`
- Delete: `vendor/opencode/`

- [ ] **Step 1: Move the vendored OpenCode directories**

```bash
mkdir -p runtime/openpod/vendor/opencode/packages runtime/openpod/vendor/opencode/skills
mv vendor/opencode/packages/superpowers runtime/openpod/vendor/opencode/packages/
mv vendor/opencode/skills/.gitkeep runtime/openpod/vendor/opencode/skills/.gitkeep
rmdir vendor/opencode/skills
rmdir vendor/opencode/packages
rmdir vendor/opencode
```

- [ ] **Step 2: Rewire the OpenCode Dockerfiles to copy flavor-owned assets**

```dockerfile
COPY runtime/openpod/vendor/opencode /opt/vendor/opencode
COPY runtime/openpod/config/opencode.json /root/.config/opencode/config.json
COPY runtime/openpod/bin/openpod-shell /usr/local/bin/openpod-shell
RUN mkdir -p /root/.config/opencode/plugins \
    && ln -sf /opt/vendor/opencode/packages/superpowers/.opencode/plugins/superpowers.js /root/.config/opencode/plugins/superpowers.js \
    && ln -sfn /opt/vendor/opencode/skills /root/.config/opencode/skills \
    && chmod 0755 /usr/local/bin/openpod-shell
```

Apply the same `COPY runtime/openpod/vendor/opencode /opt/vendor/opencode` change to both `Dockerfile.openpod` and the compatibility `Dockerfile`.

- [ ] **Step 3: Copy runtime-owned OpenCode assets during bootstrap**

```bash
vendor_home="${prefix}/vendor"
openpod_runtime_vendor_home="${prefix}/runtime/openpod/vendor"

mkdir -p "${prefix}" "${bin_dir}" "${config_home}" "${data_home}" "${state_home}" "${cache_home}" "${shell_dir}"
rm -rf "${vendor_home}" "${prefix}/runtime"
cp -R "${repo_root}/vendor" "${vendor_home}"

if [[ "${flavor_name}" == "openpod" ]]; then
  mkdir -p "${openpod_runtime_vendor_home}"
  cp -R "${repo_root}/runtime/openpod/vendor/opencode" "${openpod_runtime_vendor_home}/opencode"
  export OPENPOD_OPENPOD_VENDOR_HOME="${openpod_runtime_vendor_home}"
fi
```

- [ ] **Step 4: Update the OpenCode harness installer to read from the new runtime vendor root**

```bash
openpod_vendor_home="${OPENPOD_OPENPOD_VENDOR_HOME:-${vendor_home}}"

mkdir -p "${config_home}/plugins"
cp "${repo_root}/runtime/openpod/config/opencode.json" "${config_home}/config.json"
ln -sfn "${openpod_vendor_home}/opencode/packages/superpowers/.opencode/plugins/superpowers.js" "${config_home}/plugins/superpowers.js"
ln -sfn "${openpod_vendor_home}/opencode/skills" "${config_home}/skills"
```

- [ ] **Step 5: Run the structural regression test and verify GREEN**

Run: `bash tests/test-openpod-runtime-assets.sh`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add Dockerfile Dockerfile.openpod install/bootstrap.sh runtime/openpod vendor
git commit -m "refactor: move opencode assets into openpod runtime"
```

### Task 3: Update Sync, Metadata, And Maintainer Docs

**Files:**
- Modify: `build/update-vendor-assets.sh`
- Modify: `docs/vendor-assets.md`
- Modify: `DEVELOPMENT.md`
- Modify: `AGENTS.md`
- Modify: `CLAUDE.md`
- Modify: `vendor/manifest.lock.json`

- [ ] **Step 1: Point the vendor refresh script at the new source of truth**

```bash
vendor_dir="${repo_root}/vendor"
runtime_dir="${repo_root}/runtime"
openpod_vendor_dir="${runtime_dir}/openpod/vendor"
openpod_opencode_dir="${openpod_vendor_dir}/opencode"

rm -rf "${vendor_dir}/opencode"
mkdir -p "${vendor_dir}/releases" "${vendor_dir}/nvim" "${vendor_dir}/zsh"
mkdir -p "${openpod_opencode_dir}/packages" "${openpod_opencode_dir}/skills"

download_plugin_snapshot "obra/superpowers" "refs/tags/${superpowers_version}" "${openpod_opencode_dir}/packages/superpowers"

for flavor in claudepod codexpod; do
  rm -rf "${runtime_dir}/${flavor}/skills/superpowers"
  mkdir -p "${runtime_dir}/${flavor}/skills"
  cp -R "${openpod_opencode_dir}/packages/superpowers/skills" "${runtime_dir}/${flavor}/skills/superpowers"
done
```

- [ ] **Step 2: Update machine-readable metadata**

```json
"opencode": {
  "plugin_packages": {
    "superpowers": {
      "local_path": "runtime/openpod/vendor/opencode/packages/superpowers"
    }
  },
  "global_skills": {
    "local_path": "runtime/openpod/vendor/opencode/skills"
  }
},
"runtime_flavors": {
  "openpod": {
    "skills_source": "runtime/openpod/vendor/opencode/skills"
  }
}
```

- [ ] **Step 3: Update maintainer docs to describe the new ownership boundary**

```markdown
- shared `vendor/` only contains release archives, nvim starter assets, zsh plugin snapshots, and `vendor/manifest.lock.json`
- `runtime/openpod/vendor/opencode/...` is the sole OpenCode asset root
- `build/update-vendor-assets.sh` refreshes the OpenCode snapshot into `runtime/openpod/vendor/opencode/...`
- `runtime/claudepod/skills/superpowers/` and `runtime/codexpod/skills/superpowers/` are synchronized from `runtime/openpod/vendor/opencode/packages/superpowers/skills`
```

Apply that model consistently in `docs/vendor-assets.md`, `DEVELOPMENT.md`, `AGENTS.md`, and `CLAUDE.md`.

- [ ] **Step 4: Re-run the local regression suite**

Run: `bash tests/run.sh`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add build/update-vendor-assets.sh docs/vendor-assets.md DEVELOPMENT.md AGENTS.md CLAUDE.md vendor/manifest.lock.json tests/run.sh tests/test-openpod-runtime-assets.sh
git commit -m "docs: document runtime-owned openpod assets"
```

### Task 4: Run End-To-End Verification

**Files:**
- Modify: none

- [ ] **Step 1: Refresh vendored assets from the new path**

Run: `bash build/update-vendor-assets.sh`
Expected: command succeeds and prints `Vendored assets updated under ...`

- [ ] **Step 2: Run the root smoke suite**

Run: `bash tests/run.sh`
Expected: PASS

- [ ] **Step 3: Rebuild all flavors**

Run: `docker compose build devpod openpod claudepod codexpod`
Expected: PASS

- [ ] **Step 4: Smoke-test each flavor**

Run: `docker compose run --rm openpod -lc 'opencode --version'`
Expected: prints an OpenCode version string

Run: `docker compose run --rm claudepod -lc 'claude --version && claude auth status'`
Expected: prints a Claude Code version and logged-out auth status JSON

Run: `docker compose run --rm codexpod -lc 'codex --help | sed -n "1,20p"'`
Expected: prints Codex CLI help header

- [ ] **Step 5: Re-run bootstrap for all flavors**

Run: `bash install/bootstrap.sh --flavor openpod --user`
Expected: PASS

Run: `bash install/bootstrap.sh --flavor claudepod --user`
Expected: PASS

Run: `bash install/bootstrap.sh --flavor codexpod --user`
Expected: PASS

- [ ] **Step 6: Commit the verified migration**

```bash
git add .
git commit -m "refactor: finish openpod runtime asset migration"
```
