# Remove Legacy Docker Flavor Surfaces Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Complete issue #103 by making the repository provide the host installer path only, with Docker and multi-flavor image surfaces removed from supported docs, tests, and workflows.

**Architecture:** The product surface becomes `install/bootstrap.sh` plus the Rust `omd` TUI and shell modules. Release automation publishes the `omd` binary artifact instead of GHCR images. Tests enforce the new layout so legacy Docker files cannot silently return.

**Tech Stack:** Bash tests, Rust/Cargo, GitHub Actions YAML, Markdown docs.

---

## File Map

- Delete: `Dockerfile.devpod`.
- Delete: `docker/`.
- Delete: `runtime/`.
- Delete: `.github/workflows/publish-ghcr.yml`.
- Create: `.github/workflows/release-omd.yml`.
- Create: `tests/test-host-installer-layout.sh`.
- Create: `tests/test-omd-release-workflow.sh`.
- Create: `tests/test-vendor-assets-layout.sh`.
- Delete: `tests/test-compose-flavors.sh`.
- Delete: `tests/test-openpod-runtime-assets.sh`.
- Delete: `tests/test-publish-workflow.sh`.
- Modify: `tests/run.sh`.
- Modify: `tests/test-version-docs.sh`.
- Modify: `tests/test-versions-env.sh`.
- Modify: `tests/test-neovim-lazyvim-wiring.sh`.
- Modify: `build/update-vendor-assets.sh`.
- Modify: `build/install-lazyvim.sh`.
- Modify: `tests/test-install-lazyvim.sh`.
- Modify: `README.md`, `README_EN.md`, `DEVELOPMENT.md`, `CLAUDE.md`, `AGENTS.md`, `docs/vendor-assets.md`.

---

### Task 1: Commit the issue #103 plan

- [ ] **Step 1: Verify the plan has no placeholder markers**

Run:

```bash
grep -nE '\b(TB[D]|TO[D]O|FIXM[E]|XX[X])\b' docs/superpowers/plans/2026-06-09-remove-legacy-docker-issue-103.md
```

Expected: command exits non-zero and prints nothing.

- [ ] **Step 2: Commit the plan**

Run:

```bash
git add docs/superpowers/plans/2026-06-09-remove-legacy-docker-issue-103.md
git commit -m "docs(installer): plan issue 103 legacy removal" \
  -m "Refs #103\n\nConstraint: Docker/flavor removal must be issue-driven and test-first after the omd host-installer path exists.\nConfidence: high\nScope-risk: narrow\nTested: grep placeholder scan\nNot-tested: Runtime behavior; planning-only change"
```

---

### Task 2: Add host-installer-only tests first

- [ ] **Step 1: Create `tests/test-host-installer-layout.sh`**

The test must assert:

- `install/bootstrap.sh` exists and is executable.
- `crates/omd/Cargo.toml` exists.
- `modules/core/brew.sh`, `modules/core/zsh.sh`, and `modules/core/base-tools.sh` exist.
- `modules/optional/claude-code.sh`, `modules/optional/codex.sh`, `modules/optional/opencode.sh`, `modules/optional/copilot.sh`, and `modules/optional/gemini.sh` exist.
- `Dockerfile.devpod`, `docker/`, and `runtime/` do not exist.
- `README.md` and `README_EN.md` do not contain `ghcr.io/zhangdw156`, `docker compose`, or `Dockerfile.devpod`.

- [ ] **Step 2: Create `tests/test-omd-release-workflow.sh`**

The test must assert `.github/workflows/release-omd.yml` exists and contains:

- `cargo build --release -p omd`.
- `omd-x86_64-unknown-linux-gnu.tar.gz`.
- `softprops/action-gh-release`.
- no `docker/build-push-action`.
- no `ghcr.io`.

- [ ] **Step 3: Create `tests/test-vendor-assets-layout.sh`**

The test must assert:

- `vendor/opencode` does not exist.
- `runtime` does not exist.
- `build/update-vendor-assets.sh` does not mention `runtime/`, `openpod`, `claudepod`, `codexpod`, `copilotpod`, or `geminipod`.
- `build/update-vendor-assets.sh` still refreshes `vendor/zsh` and `vendor/nvim/lazyvim-starter`.

- [ ] **Step 4: Run new tests and verify RED**

Run:

```bash
bash tests/test-host-installer-layout.sh
bash tests/test-omd-release-workflow.sh
bash tests/test-vendor-assets-layout.sh
```

Expected: at least one test fails because legacy files and workflow still exist.

---

### Task 3: Remove Docker/flavor files and replace release workflow

- [ ] **Step 1: Remove legacy product files**

Run:

```bash
rm -rf Dockerfile.devpod docker runtime .github/workflows/publish-ghcr.yml
```

- [ ] **Step 2: Add `.github/workflows/release-omd.yml`**

Create a workflow that runs on version tags and manual dispatch, builds `omd` on Ubuntu 24.04, packages `target/release/omd` as `omd-x86_64-unknown-linux-gnu.tar.gz`, creates a SHA256 file, and uploads both with `softprops/action-gh-release`.

- [ ] **Step 3: Run release workflow test and verify GREEN**

Run:

```bash
bash tests/test-omd-release-workflow.sh
```

Expected: PASS.

---

### Task 4: Simplify vendor and LazyVim ownership

- [ ] **Step 1: Update `build/update-vendor-assets.sh`**

Remove OpenCode/superpowers runtime synchronization and keep only shared assets:

- release binaries under `vendor/releases`,
- zsh plugins under `vendor/zsh`,
- LazyVim starter under `vendor/nvim/lazyvim-starter`.

Write LazyVim source metadata to `.oh-my-devpod-source-commit` instead of `.openpod-source-commit`.

- [ ] **Step 2: Update `build/install-lazyvim.sh` and its test**

Rename openpod-specific backup suffixes and metadata fields to oh-my-devpod naming:

- backup suffix `.oh-my-devpod.bak.<timestamp>`,
- managed marker value `oh-my-devpod`,
- metadata field `oh_my_devpod_version`.

- [ ] **Step 3: Update wiring tests**

Change `tests/test-neovim-lazyvim-wiring.sh` so it checks host-installer scripts/modules instead of `Dockerfile.devpod`.

- [ ] **Step 4: Run asset tests**

Run:

```bash
bash tests/test-install-lazyvim.sh
bash tests/test-neovim-lazyvim-wiring.sh
bash tests/test-vendor-assets-layout.sh
```

Expected: PASS.

---

### Task 5: Update test runner and version/doc tests

- [ ] **Step 1: Update `tests/run.sh`**

Remove deleted tests and add the new host-installer tests.

- [ ] **Step 2: Update `tests/test-version-docs.sh`**

Check docs for `VERSION`, `omd`, `install/bootstrap.sh`, and `cargo test -p omd`. Assert they do not advertise `IMAGE_VERSION`, `ghcr.io/zhangdw156`, or `docker compose`.

- [ ] **Step 3: Update `tests/test-versions-env.sh`**

Remove Dockerfile ARG checks. Keep checks that build install scripts use `versions.env` fallbacks and that `build/update-vendor-assets.sh` sources `versions.env`.

- [ ] **Step 4: Run tests and verify GREEN**

Run:

```bash
bash tests/run.sh
```

Expected: PASS.

---

### Task 6: Update docs and guidance

- [ ] **Step 1: Rewrite user docs**

Update `README.md` and `README_EN.md` so they contain only the host-installer product path. Remove legacy Docker usage sections.

- [ ] **Step 2: Rewrite maintainer docs**

Update `DEVELOPMENT.md`, `CLAUDE.md`, and `AGENTS.md` to describe:

- `install/bootstrap.sh`,
- `crates/omd`,
- `modules/`,
- `build/`, `config/`, and `vendor/`,
- `bash tests/run.sh`,
- `cargo test -p omd`,
- GitHub Release binary publication.

- [ ] **Step 3: Update vendor docs**

Update `docs/vendor-assets.md` so it no longer describes OpenCode runtime vendor assets or flavor skill synchronization.

- [ ] **Step 4: Run doc tests**

Run:

```bash
bash tests/test-version-docs.sh
rg -n "ghcr.io/zhangdw156|docker compose|Dockerfile.devpod|openpod|claudepod|codexpod|copilotpod|geminipod|IMAGE_VERSION" README.md README_EN.md DEVELOPMENT.md CLAUDE.md AGENTS.md docs/vendor-assets.md
```

Expected: the doc test passes and the `rg` command exits non-zero.

---

### Task 7: Full verification and commit

- [ ] **Step 1: Run full validation**

Run:

```bash
cargo fmt --all -- --check
bash tests/run.sh
cargo test -p omd
git diff --check
```

Expected: all pass.

- [ ] **Step 2: Commit issue #103 changes**

Run:

```bash
git add -A
git commit -m "refactor(installer): remove issue 103 docker flavor surfaces" \
  -m "Refs #103\n\nConstraint: The project is now a host-installer product centered on omd rather than Docker images.\nRejected: Keeping Docker files as legacy supported surfaces | User asked to complete the migration to the sh installer path only.\nConfidence: medium\nScope-risk: broad\nTested: cargo fmt --all -- --check; bash tests/run.sh; cargo test -p omd; git diff --check\nNot-tested: Live GitHub Release upload"
```

---

### Task 8: Update GitHub issue

- [ ] **Step 1: Post completion comment**

Run:

```bash
gh issue comment 103 --body "Removed legacy Docker/flavor product surfaces and rewired docs/tests/workflow around the omd host installer. Verification: cargo fmt --all -- --check; bash tests/run.sh; cargo test -p omd; git diff --check."
```

Expected: issue #103 has a completion comment.
