# Centralized Image Version Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make a root `VERSION` file the only version source for `devpod`, `openpod`, `claudepod`, and `codexpod`.

**Architecture:** The root `VERSION` file becomes the release source of truth, pod-local compose files consume it through `${IMAGE_VERSION:-local}` defaults, and the publish workflow reads it directly instead of parsing compose files. Regression tests enforce that compose files stop hard-coding release tags and that the workflow and docs reference `VERSION`.

**Tech Stack:** Bash, Docker Compose YAML, GitHub Actions YAML, Markdown docs

---

## File Structure

- Create: `VERSION`
- Create: `tests/test-publish-workflow.sh`
- Create: `tests/test-version-docs.sh`
- Modify: `docker/openpod/docker-compose.yaml`
- Modify: `docker/claudepod/docker-compose.yaml`
- Modify: `docker/codexpod/docker-compose.yaml`
- Modify: `.github/workflows/publish-ghcr.yml`
- Modify: `tests/test-compose-flavors.sh`
- Modify: `tests/run.sh`
- Modify: `README.md`
- Modify: `README_EN.md`
- Modify: `DEVELOPMENT.md`
- Modify: `AGENTS.md`
- Modify: `CLAUDE.md`

### Task 1: Centralize Local Compose Image Tags

**Files:**
- Create: `VERSION`
- Modify: `docker/openpod/docker-compose.yaml`
- Modify: `docker/claudepod/docker-compose.yaml`
- Modify: `docker/codexpod/docker-compose.yaml`
- Modify: `tests/test-compose-flavors.sh`

- [ ] **Step 1: Write the failing compose/version regression test**

Replace `tests/test-compose-flavors.sh` with:

```bash
#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

[[ -f "${repo_root}/VERSION" ]] || fail "missing VERSION file"
[[ ! -f "${repo_root}/Dockerfile" ]] || fail "root Dockerfile should not exist"
[[ ! -f "${repo_root}/docker-compose.yml" ]] || fail "root docker-compose.yml should not exist"

version="$(tr -d '\n' < "${repo_root}/VERSION")"
[[ -n "${version}" ]] || fail "VERSION file should not be empty"

check_compose() {
  local flavor="$1"
  local compose_file="${repo_root}/docker/${flavor}/docker-compose.yaml"
  local tmp_out

  [[ -f "${compose_file}" ]] || fail "missing compose file: ${compose_file}"
  rg -q 'image: oh-my-devpod:\$\{IMAGE_VERSION:-local\}' "${compose_file}" \
    || fail "compose should use IMAGE_VERSION for devpod in ${compose_file}"
  rg -q "image: oh-my-${flavor}:\$\{IMAGE_VERSION:-local\}" "${compose_file}" \
    || fail "compose should use IMAGE_VERSION for ${flavor} in ${compose_file}"
  if rg -q "image: oh-my-(devpod|${flavor}):${version}" "${compose_file}"; then
    fail "compose should not hard-code ${version} in ${compose_file}"
  fi

  tmp_out="$(mktemp)"
  IMAGE_VERSION=test-version docker compose -f "${compose_file}" config > "${tmp_out}"

  for service in devpod "${flavor}"; do
    if ! rg -q "^  ${service}:" "${tmp_out}"; then
      fail "missing compose service ${service} in ${compose_file}"
    fi
  done

  for dockerfile in \
    "dockerfile: Dockerfile.devpod" \
    "dockerfile: docker/${flavor}/Dockerfile"; do
    if ! rg -q "${dockerfile}" "${tmp_out}"; then
      fail "missing compose dockerfile path ${dockerfile} in ${compose_file}"
    fi
  done

  if ! rg -q 'image: oh-my-devpod:test-version' "${tmp_out}"; then
    fail "compose should render IMAGE_VERSION for devpod in ${compose_file}"
  fi
  if ! rg -q "image: oh-my-${flavor}:test-version" "${tmp_out}"; then
    fail "compose should render IMAGE_VERSION for ${flavor} in ${compose_file}"
  fi

  if rg -q "^\\s+env_file:" "${tmp_out}"; then
    fail "compose should not define env_file entries in ${compose_file}"
  fi

  rm -f "${tmp_out}"
}

for flavor in openpod claudepod codexpod; do
  check_compose "${flavor}"
done
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test-compose-flavors.sh`
Expected: FAIL with `missing VERSION file`

- [ ] **Step 3: Write minimal implementation**

Create `VERSION` with:

```text
0.4.0.dev5
```

Replace `docker/openpod/docker-compose.yaml` with:

```yaml
services:
  devpod:
    build:
      context: ../..
      dockerfile: Dockerfile.devpod
      network: host
    image: oh-my-devpod:${IMAGE_VERSION:-local}
  openpod:
    build:
      context: ../..
      dockerfile: docker/openpod/Dockerfile
      network: host
      additional_contexts:
        devpod: service:devpod
      args:
        DEVPOD_BASE_IMAGE: devpod
    image: oh-my-openpod:${IMAGE_VERSION:-local}
    container_name: openpod
    stdin_open: true
    tty: true
    working_dir: /workspace
    volumes:
      - ${PROJECT_DIR:-../..}:/workspace
    network_mode: host
    restart: "no"
```

Replace `docker/claudepod/docker-compose.yaml` with:

```yaml
services:
  devpod:
    build:
      context: ../..
      dockerfile: Dockerfile.devpod
      network: host
    image: oh-my-devpod:${IMAGE_VERSION:-local}
  claudepod:
    build:
      context: ../..
      dockerfile: docker/claudepod/Dockerfile
      network: host
      additional_contexts:
        devpod: service:devpod
      args:
        DEVPOD_BASE_IMAGE: devpod
    image: oh-my-claudepod:${IMAGE_VERSION:-local}
    container_name: claudepod
    stdin_open: true
    tty: true
    working_dir: /workspace
    volumes:
      - ${PROJECT_DIR:-../..}:/workspace
    network_mode: host
    restart: "no"
```

Replace `docker/codexpod/docker-compose.yaml` with:

```yaml
services:
  devpod:
    build:
      context: ../..
      dockerfile: Dockerfile.devpod
      network: host
    image: oh-my-devpod:${IMAGE_VERSION:-local}
  codexpod:
    build:
      context: ../..
      dockerfile: docker/codexpod/Dockerfile
      network: host
      additional_contexts:
        devpod: service:devpod
      args:
        DEVPOD_BASE_IMAGE: devpod
    image: oh-my-codexpod:${IMAGE_VERSION:-local}
    container_name: codexpod
    stdin_open: true
    tty: true
    working_dir: /workspace
    volumes:
      - ${PROJECT_DIR:-../..}:/workspace
    network_mode: host
    restart: "no"
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/test-compose-flavors.sh`
Expected: PASS with no output

- [ ] **Step 5: Commit**

```bash
git add VERSION docker/openpod/docker-compose.yaml docker/claudepod/docker-compose.yaml docker/codexpod/docker-compose.yaml tests/test-compose-flavors.sh
git commit -m "refactor: centralize compose image version input"
```

### Task 2: Make Publish Workflow Read VERSION

**Files:**
- Create: `tests/test-publish-workflow.sh`
- Modify: `.github/workflows/publish-ghcr.yml`
- Modify: `tests/run.sh`

- [ ] **Step 1: Write the failing workflow regression test**

Create `tests/test-publish-workflow.sh` with:

```bash
#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
workflow="${repo_root}/.github/workflows/publish-ghcr.yml"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

[[ -f "${repo_root}/VERSION" ]] || fail "missing VERSION file"
[[ -f "${workflow}" ]] || fail "missing publish workflow"

rg -q 'version="\$\(tr -d '\\''\\\\n'\\'' < VERSION\)"' "${workflow}" \
  || fail "publish workflow should read VERSION"
rg -q 'echo "version=\$version" >> "\$GITHUB_OUTPUT"' "${workflow}" \
  || fail "publish workflow should export version from VERSION"

if rg -q 'extract_tag|docker/openpod/docker-compose.yaml:oh-my-openpod|docker/claudepod/docker-compose.yaml:oh-my-claudepod|docker/codexpod/docker-compose.yaml:oh-my-codexpod' "${workflow}"; then
  fail "publish workflow should not parse compose files for version tags"
fi
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test-publish-workflow.sh`
Expected: FAIL with `publish workflow should read VERSION`

- [ ] **Step 3: Write minimal implementation**

Replace the `Resolve image version` step in `.github/workflows/publish-ghcr.yml` with:

```yaml
      - name: Resolve image version
        id: version
        shell: bash
        run: |
          set -euo pipefail

          version="$(tr -d '\n' < VERSION)"
          if [[ -z "$version" ]]; then
            echo "VERSION file is empty" >&2
            exit 1
          fi

          owner="${GITHUB_REPOSITORY_OWNER,,}"
          base_image_name="ghcr.io/${owner}/oh-my-devpod"
          openpod_image_name="ghcr.io/${owner}/oh-my-openpod"
          claudepod_image_name="ghcr.io/${owner}/oh-my-claudepod"
          codexpod_image_name="ghcr.io/${owner}/oh-my-codexpod"

          publish="true"
          if [[ "$version" == *-dev || "$version" =~ \.dev[0-9]+$ ]]; then
            publish="false"
          fi

          echo "version=$version" >> "$GITHUB_OUTPUT"
          echo "base_image_name=$base_image_name" >> "$GITHUB_OUTPUT"
          echo "openpod_image_name=$openpod_image_name" >> "$GITHUB_OUTPUT"
          echo "claudepod_image_name=$claudepod_image_name" >> "$GITHUB_OUTPUT"
          echo "codexpod_image_name=$codexpod_image_name" >> "$GITHUB_OUTPUT"
          echo "publish=$publish" >> "$GITHUB_OUTPUT"
```

Append the new test to `tests/run.sh` so it becomes:

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
bash "${repo_root}/tests/test-publish-workflow.sh"
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/test-publish-workflow.sh`
Expected: PASS with no output

Run: `bash tests/run.sh`
Expected: PASS with no output

- [ ] **Step 5: Commit**

```bash
git add .github/workflows/publish-ghcr.yml tests/test-publish-workflow.sh tests/run.sh
git commit -m "refactor: read publish version from VERSION"
```

### Task 3: Update Versioning Documentation

**Files:**
- Create: `tests/test-version-docs.sh`
- Modify: `README.md`
- Modify: `README_EN.md`
- Modify: `DEVELOPMENT.md`
- Modify: `AGENTS.md`
- Modify: `CLAUDE.md`
- Modify: `tests/run.sh`

- [ ] **Step 1: Write the failing documentation regression test**

Create `tests/test-version-docs.sh` with:

```bash
#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

rg -q '`VERSION`' "${repo_root}/README.md" \
  || fail "README.md should describe VERSION as the shared version source"
rg -q '`VERSION`' "${repo_root}/README_EN.md" \
  || fail "README_EN.md should describe VERSION as the shared version source"
rg -q '`VERSION`' "${repo_root}/DEVELOPMENT.md" \
  || fail "DEVELOPMENT.md should describe VERSION as the release source of truth"
rg -q '`VERSION`' "${repo_root}/AGENTS.md" \
  || fail "AGENTS.md should mention VERSION-based image version management"
rg -q '`VERSION`' "${repo_root}/CLAUDE.md" \
  || fail "CLAUDE.md should mention VERSION-based image version management"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test-version-docs.sh`
Expected: FAIL with `README.md should describe VERSION as the shared version source`

- [ ] **Step 3: Write minimal implementation**

Update the versioning section in `DEVELOPMENT.md` to:

````md
## 版本管理

仓库根目录 `VERSION` 文件是四个镜像唯一的版本真源：

```text
0.4.0.dev5
```

`docker/<flavor>/docker-compose.yaml` 通过 `${IMAGE_VERSION:-local}` 消费这个版本；正式发布和开发版本切换都只修改 `VERSION`。

| 版本格式 | 含义 |
|----------|------|
| `x.y.z.devN` | 开发中，尚未发布 |
| `x.y.z` | 已发布的正式版本 |
````

Update the release flow block in `DEVELOPMENT.md` so the version-bump commands use:

```bash
git add VERSION
git commit -m "release: cut x.y.z"
```

and later:

```bash
git add VERSION
git commit -m "chore: bump version to <next-version>.dev0"
```

Add this line to `README.md` under the Docker usage section:

```md
- 仓库根目录 `VERSION` 是四个镜像共享的版本真源；pod-local compose 仅消费它，不再保存发布版本号
```

Add this line to `README_EN.md` under the Docker usage section:

```md
- The repository-root `VERSION` file is the shared source of truth for all four image tags; pod-local compose files only consume it
```

Update the project structure line in `AGENTS.md` to:

```md
`Dockerfile.devpod` defines the shared base image, each `docker/<flavor>/` directory owns that flavor's `Dockerfile` plus `docker-compose.yaml`, and the repository-root `VERSION` file is the shared source of truth for all four image tags.
```

Update the release/version bullets in `CLAUDE.md` to:

```md
- The single source of truth for image versions is the root `VERSION` file.
- Pod-local compose files consume `${IMAGE_VERSION:-local}` and are not release metadata authorities.
- `.github/workflows/publish-ghcr.yml` reads `VERSION` directly.
```

Append the new test to `tests/run.sh` so it becomes:

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
bash "${repo_root}/tests/test-publish-workflow.sh"
bash "${repo_root}/tests/test-version-docs.sh"
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/test-version-docs.sh`
Expected: PASS with no output

Run: `bash tests/run.sh`
Expected: PASS with no output

- [ ] **Step 5: Commit**

```bash
git add README.md README_EN.md DEVELOPMENT.md AGENTS.md CLAUDE.md tests/test-version-docs.sh tests/run.sh
git commit -m "docs: describe VERSION-based image versioning"
```
