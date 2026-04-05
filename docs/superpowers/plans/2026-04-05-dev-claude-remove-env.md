# `dev/claude` Remove `.env` Runtime Support Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove `.env`-driven authentication/configuration support from `dev/claude` so the branch relies only on native Claude Code login and user-managed Claude config.

**Architecture:** Delete the sync layer and all `.env` ingestion points, simplify the Claude wrapper to directly execute the installed binary, remove `.env` references from Docker/bootstrap/docs/tests, and keep only Claude-native configuration paths such as `claude auth login` and user-managed `~/.claude` or project-local `.claude/`.

**Tech Stack:** Bash, Docker, docker compose, shell-based smoke tests, Claude Code native binary install

---

### Task 1: Replace `.env`-Sync Tests With Native Runtime Tests

**Files:**
- Delete: `tests/test-claudepod-sync-config.sh`
- Modify: `tests/run.sh`
- Modify: `tests/test-claudepod-shell-wrappers.sh`

- [ ] **Step 1: Update the wrapper test so it no longer expects the sync hook**

```bash
#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp_home="$(mktemp -d)"
trap 'rm -rf "${tmp_home}"' EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

mkdir -p "${tmp_home}/bin"
cat > "${tmp_home}/bin/claude-real" <<'SH'
#!/usr/bin/env bash
printf 'real:%s\n' "$*"
SH
chmod +x "${tmp_home}/bin/claude-real"

output="$(
  env \
    HOME="${tmp_home}" \
    OPENPOD_CLAUDE_REAL_BIN="${tmp_home}/bin/claude-real" \
    bash "${repo_root}/bin/claude" --version
)"

[[ "${output}" == "real:--version" ]] || fail "claude wrapper did not exec the real binary"
```

- [ ] **Step 2: Remove the sync test from the suite**

```bash
#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

bash "${repo_root}/tests/test-install-neovim.sh"
bash "${repo_root}/tests/test-install-python-dev-tools.sh"
bash "${repo_root}/tests/test-install-lazyvim.sh"
bash "${repo_root}/tests/test-neovim-lazyvim-wiring.sh"
bash "${repo_root}/tests/test-claudepod-shell-wrappers.sh"
```

- [ ] **Step 3: Run tests to verify they fail only if old `.env` expectations remain**

Run: `bash tests/test-claudepod-shell-wrappers.sh`
Expected: PASS after test update

Run: `bash tests/run.sh`
Expected: PASS after removing the deleted test from the suite

- [ ] **Step 4: Commit**

```bash
git add tests/run.sh tests/test-claudepod-shell-wrappers.sh
git rm tests/test-claudepod-sync-config.sh
git commit -m "test: remove env sync coverage from claudepod"
```

### Task 2: Remove The Sync Layer And Simplify Runtime Wrappers

**Files:**
- Modify: `bin/claude`
- Delete: `bin/claudepod-sync-config`

- [ ] **Step 1: Simplify the wrapper**

```bash
#!/usr/bin/env bash
set -euo pipefail

real_bin="${OPENPOD_CLAUDE_REAL_BIN:-}"
if [[ -z "${real_bin}" || ! -x "${real_bin}" ]]; then
  echo "claude real binary not found: ${real_bin:-unset}" >&2
  exit 1
fi

exec "${real_bin}" "$@"
```

- [ ] **Step 2: Remove the sync script entirely**

```bash
git rm bin/claudepod-sync-config
```

- [ ] **Step 3: Run the focused wrapper test**

Run: `bash tests/test-claudepod-shell-wrappers.sh`
Expected: PASS

- [ ] **Step 4: Commit**

```bash
git add bin/claude
git commit -m "refactor: remove claudepod sync layer"
```

### Task 3: Remove `.env` Wiring From Docker And Bootstrap

**Files:**
- Modify: `docker-compose.yml`
- Modify: `Dockerfile`
- Modify: `install/bootstrap.sh`

- [ ] **Step 1: Remove compose-level `.env` ingestion**

```yaml
services:
  claudepod:
    build:
      context: .
      network: host
    image: oh-my-claudepod:0.4.0.dev5
    container_name: claudepod
    stdin_open: true
    tty: true
    working_dir: /workspace
    volumes:
      - ${PROJECT_DIR:-.}:/workspace
    network_mode: host
    restart: "no"
```

- [ ] **Step 2: Remove sync-script installation from Dockerfile**

```dockerfile
ENV OPENPOD_CLAUDE_BASE_SETTINGS=/opt/openpod-config/claude/settings.base.json
ENV OPENPOD_CLAUDE_REAL_BIN=/usr/local/bin/claude-real

COPY bin/claude /usr/local/bin/claude
COPY bin/claudepod-shell /usr/local/bin/claudepod-shell
COPY bin/openpod-shell /usr/local/bin/openpod-shell
RUN chmod 0755 /usr/local/bin/claude /usr/local/bin/claudepod-shell /usr/local/bin/openpod-shell
```

- [ ] **Step 3: Remove sync-related exports from bootstrap**

```bash
export OPENPOD_CLAUDE_BASE_SETTINGS="${managed_config_dir}/settings.base.json"
export OPENPOD_CLAUDE_REAL_BIN="${bin_dir}/claude-real"

install -m 0755 "${repo_root}/bin/claude" "${bin_dir}/claude"
install -m 0755 "${repo_root}/bin/claudepod-shell" "${bin_dir}/claudepod-shell"
install -m 0755 "${repo_root}/bin/openpod-shell" "${bin_dir}/openpod-shell"
```

- [ ] **Step 4: Verify Docker/bootstrap syntax**

Run: `docker compose config`
Expected: PASS with no `env_file` section

Run: `bash -n install/bootstrap.sh`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add docker-compose.yml Dockerfile install/bootstrap.sh
git commit -m "refactor: remove env wiring from claudepod runtime"
```

### Task 4: Rewrite Docs Around Native Claude Configuration

**Files:**
- Delete: `.env.example`
- Modify: `README.md`
- Modify: `README_EN.md`
- Modify: `docs/vendor-assets.md`

- [ ] **Step 1: Delete the misleading `.env` template**

```bash
git rm .env.example
```

- [ ] **Step 2: Rewrite usage docs around native Claude config**

```markdown
Authenticate with one of the native Claude paths:

- run `claude auth login`
- mount or reuse your own `~/.claude`
- maintain project-local `.claude/settings.json`

`dev/claude` does not consume `.env` and does not auto-generate Claude auth settings.
```

- [ ] **Step 3: Rewrite vendor docs to remove managed auth wording**

```markdown
The branch ships the Claude binary and skills layout, but authentication is entirely user-managed through Claude's native config and login flow.
```

- [ ] **Step 4: Verify no runtime `.env` claims remain**

Run: `rg -n "\\.env|env_file|clau?depod-sync-config|OPENPOD_SOURCE_REPO|OPENPOD_CLAUDE_SYNC_BIN" README.md README_EN.md Dockerfile docker-compose.yml install/bootstrap.sh docs/vendor-assets.md`
Expected: no matches that describe active runtime behavior

- [ ] **Step 5: Commit**

```bash
git add README.md README_EN.md docs/vendor-assets.md
git commit -m "docs: remove env-based auth flow from claudepod"
```

### Task 5: Re-Verify Native-Only Runtime Behavior

**Files:**
- Modify: `docs/superpowers/plans/2026-04-05-dev-claude-remove-env.md` only if final verification notes must change

- [ ] **Step 1: Run the shell-based test suite**

Run: `bash tests/run.sh`
Expected: PASS

- [ ] **Step 2: Rebuild the image**

Run: `docker compose build`
Expected: PASS

- [ ] **Step 3: Verify native runtime status inside the container**

Run: `docker compose run --rm claudepod -lc 'claude --version && claude auth status'`
Expected: PASS with `loggedIn: false` when no user config is mounted

- [ ] **Step 4: Verify bootstrap still works without `.env`**

Run: `tmp_home="$(mktemp -d)" && tmp_prefix="${tmp_home}/.local/claudepod" && env HOME="${tmp_home}" bash install/bootstrap.sh --user --prefix "${tmp_prefix}" && env HOME="${tmp_home}" OPENPOD_PREFIX="${tmp_prefix}" "${tmp_home}/.local/bin/claudepod-shell" -lc 'claude --version && claude auth status'`
Expected: PASS with no generated auth settings

- [ ] **Step 5: Verify `.env` is no longer part of the branch**

Run: `rg -n "\\.env.example|env_file:|OPENPOD_SOURCE_REPO|OPENPOD_CLAUDE_SYNC_BIN|claudepod-sync-config" .`
Expected: only historical references in old plan/spec docs, if any

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat: remove env support from dev/claude"
```
