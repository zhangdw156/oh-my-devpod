# Multi-Flavor `devpod` Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refactor the repository from a single OpenCode-specific product into a shared `devpod` base with three thin runtime flavors: `openpod`, `claudepod`, and `codexpod`.

**Architecture:** Extract all shared system/editor/shell tooling into `Dockerfile.devpod` and shared bootstrap logic, move harness-specific installation/config/skills into `runtime/<flavor>/`, and build three image flavors plus one flavor-aware bootstrap entrypoint from the same `main` branch. Implement in phases so `openpod` becomes the first flavor on the new architecture, then layer in `claudepod` and `codexpod`.

**Tech Stack:** Bash, Docker multi-stage builds, docker compose, shell-based smoke tests, vendored release assets, Claude Code native binary install, Codex CLI via pinned npm package

---

### Task 1: Add Failing Tests For Flavor-Aware Compose And Bootstrap

**Files:**
- Create: `tests/test-compose-flavors.sh`
- Create: `tests/test-bootstrap-flavors.sh`
- Modify: `tests/run.sh`

- [ ] **Step 1: Add a failing compose flavor test**

```bash
#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp_out="$(mktemp)"
trap 'rm -f "${tmp_out}"' EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

docker compose -f "${repo_root}/docker-compose.yml" config > "${tmp_out}"

for service in openpod claudepod codexpod; do
  if ! rg -q "^  ${service}:" "${tmp_out}"; then
    fail "missing compose service: ${service}"
  fi
done
```

- [ ] **Step 2: Verify the compose test fails**

Run: `bash tests/test-compose-flavors.sh`
Expected: FAIL because `docker-compose.yml` currently defines only `openpod`

- [ ] **Step 3: Add a failing bootstrap flavor test**

```bash
#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

help_output="$(bash "${repo_root}/install/bootstrap.sh" --help)"

printf '%s' "${help_output}" | rg -q -- '--flavor' || fail "bootstrap help missing --flavor"
for flavor in openpod claudepod codexpod; do
  printf '%s' "${help_output}" | rg -q -- "${flavor}" || fail "bootstrap help missing flavor ${flavor}"
done
```

- [ ] **Step 4: Verify the bootstrap test fails**

Run: `bash tests/test-bootstrap-flavors.sh`
Expected: FAIL because `install/bootstrap.sh` does not expose `--flavor`

- [ ] **Step 5: Register the tests**

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
```

- [ ] **Step 6: Commit**

```bash
git add tests/run.sh tests/test-compose-flavors.sh tests/test-bootstrap-flavors.sh
git commit -m "test: add multi-flavor runtime coverage"
```

### Task 2: Extract Shared `devpod` Base And OpenCode Flavor

**Files:**
- Create: `Dockerfile.devpod`
- Create: `Dockerfile.openpod`
- Create: `runtime/openpod/install-harness.sh`
- Create: `runtime/openpod/bin/openpod-shell`
- Create: `runtime/openpod/config/opencode.json`
- Create: `runtime/openpod/skills/.gitkeep`
- Modify: `Dockerfile`
- Modify: `docker-compose.yml`
- Modify: `install/bootstrap.sh`

- [ ] **Step 1: Create the shared base Dockerfile**

```dockerfile
FROM ubuntu:24.04 AS devpod-base

RUN apt-get update && apt-get install -y --no-install-recommends \
    bzip2 \
    curl \
    fd-find \
    file \
    gcc \
    git \
    make \
    ripgrep \
    tzdata \
    unzip \
    vim \
    zsh \
    ca-certificates \
    musl \
    && rm -rf /var/lib/apt/lists/*

COPY vendor /opt/vendor

ARG TARGETARCH
COPY build/install-btop.sh /tmp/install-btop.sh
RUN bash /tmp/install-btop.sh && rm -f /tmp/install-btop.sh
COPY build/install-antidote.sh /tmp/install-antidote.sh
RUN bash /tmp/install-antidote.sh && rm -f /tmp/install-antidote.sh
COPY build/install-zellij.sh /tmp/install-zellij.sh
RUN bash /tmp/install-zellij.sh && rm -f /tmp/install-zellij.sh
COPY build/install-yazi.sh /tmp/install-yazi.sh
RUN bash /tmp/install-yazi.sh && rm -f /tmp/install-yazi.sh
COPY build/install-neovim.sh /tmp/install-neovim.sh
RUN bash /tmp/install-neovim.sh && rm -f /tmp/install-neovim.sh
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /usr/local/bin/
COPY build/install-python-dev-tools.sh /tmp/install-python-dev-tools.sh
RUN bash /tmp/install-python-dev-tools.sh && rm -f /tmp/install-python-dev-tools.sh
COPY config/nvim /opt/devpod-config/nvim
COPY build/install-lazyvim.sh /tmp/install-lazyvim.sh
RUN OHMYDEVPOD_NVM_OVERLAY_DIR=/opt/devpod-config/nvim bash /tmp/install-lazyvim.sh && rm -f /tmp/install-lazyvim.sh

ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8
ENV OHMYDEVPOD_LAZYVIM_STARTER_COMMIT=803bc181d7c0d6d5eeba9274d9be49b287294d99
ENV OHMYDEVPOD_LAZYVIM_SOURCE_DIR=/opt/vendor/nvim/lazyvim-starter
ENV OHMYDEVPOD_NEOVIM_DIR=/opt/neovim
ENV OHMYDEVPOD_NVM_OVERLAY_DIR=/opt/devpod-config/nvim
ENV OHMYDEVPOD_PYRIGHT_VERSION=1.1.408
ENV OHMYDEVPOD_RUFF_VERSION=0.15.9
ENV OHMYDEVPOD_UV_TOOL_DIR=/opt/uv-tools
ENV TERM=xterm-256color
ENV SHELL=/bin/zsh
ENV UV_LINK_MODE=copy
ENV TZ=Asia/Shanghai
RUN ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
RUN if command -v fdfind >/dev/null 2>&1 && ! command -v fd >/dev/null 2>&1; then ln -sf "$(command -v fdfind)" /usr/local/bin/fd; fi
RUN git config --global --add safe.directory '*'
COPY config/.zshrc /root/.zshrc
COPY config/.p10k.zsh /root/.p10k.zsh
WORKDIR /workspace
ENTRYPOINT ["/bin/zsh"]
```

- [ ] **Step 2: Create the OpenCode flavor Dockerfile**

```dockerfile
FROM devpod-base AS openpod

RUN mkdir -p /root/.config/opencode/plugins \
    && ln -sf /opt/vendor/opencode/packages/superpowers/.opencode/plugins/superpowers.js /root/.config/opencode/plugins/superpowers.js \
    && ln -sfn /opt/vendor/opencode/skills /root/.config/opencode/skills

COPY --from=ghcr.io/anomalyco/opencode /usr/local/bin/opencode /usr/local/bin/opencode
COPY --from=ghcr.io/anomalyco/opencode /usr/lib/libstdc++.so.6 /usr/lib/musl-compat/libstdc++.so.6
COPY --from=ghcr.io/anomalyco/opencode /usr/lib/libgcc_s.so.1 /usr/lib/musl-compat/libgcc_s.so.1
RUN echo "/lib:/usr/local/lib:/usr/lib:/usr/lib/musl-compat" > /etc/ld-musl-x86_64.path

COPY runtime/openpod/config/opencode.json /root/.config/opencode/config.json
COPY runtime/openpod/bin/openpod-shell /usr/local/bin/openpod-shell
RUN chmod 0755 /usr/local/bin/openpod-shell
```

- [ ] **Step 3: Move OpenCode-specific config into the flavor directory**

```json
{
  "provider": {}
}
```

Use the current `config/opencode.json` content as the actual file body when moving it to `runtime/openpod/config/opencode.json`.

- [ ] **Step 4: Add a flavor-aware compose file**

```yaml
services:
  openpod:
    build:
      context: .
      dockerfile: Dockerfile.openpod
      network: host
    image: oh-my-openpod:0.4.0.dev5
    container_name: openpod
    stdin_open: true
    tty: true
    working_dir: /workspace
    volumes:
      - ${PROJECT_DIR:-.}:/workspace
    network_mode: host
    restart: "no"
```

- [ ] **Step 5: Add bootstrap `--flavor` parsing for OpenCode**

```bash
flavor="openpod"

case "$1" in
  --flavor)
    flavor="$2"
    shift 2
    ;;
esac

case "${flavor}" in
  openpod) ;;
  claudepod|codexpod) ;;
  *)
    echo "Unsupported flavor: ${flavor}" >&2
    exit 1
    ;;
esac
```

At this step, only `openpod` needs to be fully wired; `claudepod` and `codexpod` may error with an explicit "not yet implemented" message until later tasks.

- [ ] **Step 6: Run the new tests**

Run: `bash tests/test-compose-flavors.sh`
Expected: FAIL until the other two services are added in later tasks

Run: `bash tests/test-bootstrap-flavors.sh`
Expected: PASS once `--flavor` help text is present

- [ ] **Step 7: Commit**

```bash
git add Dockerfile.devpod Dockerfile.openpod docker-compose.yml install/bootstrap.sh runtime/openpod
git commit -m "refactor: extract devpod base and openpod flavor"
```

### Task 3: Add `claudepod` Flavor On Top Of The Shared Base

**Files:**
- Create: `Dockerfile.claudepod`
- Create: `runtime/claudepod/install-harness.sh`
- Create: `runtime/claudepod/bin/claudepod-shell`
- Create: `runtime/claudepod/bin/claude`
- Create: `runtime/claudepod/config/`
- Create: `runtime/claudepod/skills/`
- Modify: `docker-compose.yml`
- Modify: `install/bootstrap.sh`
- Modify: `build/update-vendor-assets.sh`
- Modify: `vendor/manifest.lock.json`
- Modify: `docs/vendor-assets.md`

- [ ] **Step 1: Vendor the Claude skills tree into a flavor-owned directory**

Move the current `dev/claude` branch's `vendor/claude/skills` content into `runtime/claudepod/skills/`, preserving the `superpowers` subtree and the repo-managed `oh-my-claudepod` placeholder.

- [ ] **Step 2: Create the Claude flavor Dockerfile**

```dockerfile
FROM devpod-base AS claudepod

COPY build/install-claude-code.sh /tmp/install-claude-code.sh
RUN OHMYDEVPOD_BIN_DIR=/usr/local/bin OHMYDEVPOD_CLAUDE_INSTALL_HOME=/root bash /tmp/install-claude-code.sh \
    && rm -f /tmp/install-claude-code.sh

RUN mkdir -p /root/.claude \
    && ln -sfn /opt/runtime/claudepod/skills /root/.claude/skills

COPY runtime/claudepod/bin/claude /usr/local/bin/claude
COPY runtime/claudepod/bin/claudepod-shell /usr/local/bin/claudepod-shell
COPY runtime/claudepod/bin/openpod-shell /usr/local/bin/openpod-shell
RUN chmod 0755 /usr/local/bin/claude /usr/local/bin/claudepod-shell /usr/local/bin/openpod-shell
```

- [ ] **Step 3: Add compose and bootstrap flavor entries**

Extend compose:

```yaml
  claudepod:
    build:
      context: .
      dockerfile: Dockerfile.claudepod
      network: host
    image: oh-my-claudepod:0.4.0.dev5
    container_name: claudepod
```

Extend bootstrap dispatch:

```bash
case "${flavor}" in
  openpod)
    bash "${repo_root}/runtime/openpod/install-harness.sh"
    ;;
  claudepod)
    bash "${repo_root}/runtime/claudepod/install-harness.sh"
    ;;
esac
```

- [ ] **Step 4: Run flavor verification**

Run: `docker compose run --rm claudepod -lc 'claude --version && claude auth status'`
Expected: PASS with `loggedIn: false`

- [ ] **Step 5: Commit**

```bash
git add Dockerfile.claudepod docker-compose.yml install/bootstrap.sh runtime/claudepod build/update-vendor-assets.sh vendor/manifest.lock.json docs/vendor-assets.md
git commit -m "feat: add claudepod flavor on devpod base"
```

### Task 4: Add `codexpod` Flavor On Top Of The Shared Base

**Files:**
- Create: `Dockerfile.codexpod`
- Create: `runtime/codexpod/install-harness.sh`
- Create: `runtime/codexpod/bin/codexpod-shell`
- Create: `runtime/codexpod/bin/codex`
- Create: `runtime/codexpod/config/config.toml`
- Create: `runtime/codexpod/skills/`
- Modify: `docker-compose.yml`
- Modify: `install/bootstrap.sh`

- [ ] **Step 1: Create the Codex install helper**

```bash
#!/usr/bin/env bash
set -euo pipefail

if ! command -v node >/dev/null 2>&1 || ! command -v npm >/dev/null 2>&1; then
  apt-get update
  apt-get install -y --no-install-recommends nodejs npm
  rm -rf /var/lib/apt/lists/*
fi

npm install -g @openai/codex@0.118.0
```

For bootstrap mode, adapt this helper to install node/npm if missing on the host, then install the pinned Codex CLI globally into the target prefix environment.

- [ ] **Step 2: Create the Codex flavor Dockerfile**

```dockerfile
FROM devpod-base AS codexpod

COPY runtime/codexpod/install-harness.sh /tmp/install-codex.sh
RUN bash /tmp/install-codex.sh && rm -f /tmp/install-codex.sh

RUN mkdir -p /root/.codex \
    && ln -sfn /opt/runtime/codexpod/skills /root/.codex/skills

COPY runtime/codexpod/config/config.toml /root/.codex/config.toml
COPY runtime/codexpod/bin/codex /usr/local/bin/codex
COPY runtime/codexpod/bin/codexpod-shell /usr/local/bin/codexpod-shell
RUN chmod 0755 /usr/local/bin/codex /usr/local/bin/codexpod-shell
```

- [ ] **Step 3: Extend compose and bootstrap**

Extend compose:

```yaml
  codexpod:
    build:
      context: .
      dockerfile: Dockerfile.codexpod
      network: host
    image: oh-my-codexpod:0.4.0.dev5
    container_name: codexpod
```

Extend bootstrap dispatch:

```bash
  codexpod)
    bash "${repo_root}/runtime/codexpod/install-harness.sh"
    ;;
```

- [ ] **Step 4: Run flavor verification**

Run: `docker compose run --rm codexpod -lc 'codex --help | head -20'`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Dockerfile.codexpod docker-compose.yml install/bootstrap.sh runtime/codexpod
git commit -m "feat: add codexpod flavor on devpod base"
```

### Task 5: Rewrite Docs And Release Guidance For Multi-Flavor Main

**Files:**
- Modify: `README.md`
- Modify: `README_EN.md`
- Modify: `AGENTS.md`
- Modify: `DEVELOPMENT.md`
- Modify: `.github/workflows/`

- [ ] **Step 1: Rewrite the README to explain shared base plus flavor choice**

```markdown
This repository now builds three runtime flavors from one shared `devpod` base:

- `openpod`
- `claudepod`
- `codexpod`

All three share the same shell, editor, terminal tools, and base environment.
They differ only in harness and preinstalled skills.
```

- [ ] **Step 2: Document flavor-specific bootstrap usage**

```bash
bash install/bootstrap.sh --flavor openpod --user
bash install/bootstrap.sh --flavor claudepod --user
bash install/bootstrap.sh --flavor codexpod --user
```

- [ ] **Step 3: Document flavor-specific Docker usage**

```bash
docker compose up -d openpod
docker compose up -d claudepod
docker compose up -d codexpod
```

- [ ] **Step 4: Update release guidance to publish all flavor images from one version**

```text
ghcr.io/zhangdw156/oh-my-openpod:<tag>
ghcr.io/zhangdw156/oh-my-claudepod:<tag>
ghcr.io/zhangdw156/oh-my-codexpod:<tag>
```

- [ ] **Step 5: Commit**

```bash
git add README.md README_EN.md AGENTS.md DEVELOPMENT.md .github/workflows
git commit -m "docs: describe multi-flavor devpod architecture"
```

### Task 6: Final Verification Across The Matrix

**Files:**
- Modify: `tests/run.sh` only if final matrix verification helpers are added

- [ ] **Step 1: Run the shell test suite**

Run: `bash tests/run.sh`
Expected: PASS

- [ ] **Step 2: Build all flavor images**

Run: `docker compose build openpod claudepod codexpod`
Expected: PASS

- [ ] **Step 3: Smoke-test each flavor**

Run: `docker compose run --rm openpod -lc 'opencode --version'`
Expected: PASS

Run: `docker compose run --rm claudepod -lc 'claude --version && claude auth status'`
Expected: PASS

Run: `docker compose run --rm codexpod -lc 'codex --help | head -20'`
Expected: PASS

- [ ] **Step 4: Verify bootstrap for each flavor**

Run: `tmp_home="$(mktemp -d)" && env HOME="${tmp_home}" bash install/bootstrap.sh --flavor openpod --user`
Expected: PASS

Run: `tmp_home="$(mktemp -d)" && env HOME="${tmp_home}" bash install/bootstrap.sh --flavor claudepod --user`
Expected: PASS

Run: `tmp_home="$(mktemp -d)" && env HOME="${tmp_home}" bash install/bootstrap.sh --flavor codexpod --user`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: ship multi-flavor devpod architecture"
```
