# omd Host Installer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement issue #102 by adding the first verified host-installer path: `curl | bash` bootstrap, a prebuilt Rust TUI command named `omd`, and shell component modules with lifecycle contracts.

**Architecture:** `install/bootstrap.sh` remains a small Bash bootstrapper that validates Ubuntu 24.04 and installs a release binary into `~/.local/bin/omd`. `crates/omd` owns CLI/TUI state and component selection. `modules/` owns component lifecycle actions through a stable shell interface.

**Tech Stack:** Bash, Rust workspace, Ratatui, Crossterm, Cargo tests, existing shell test runner.

---

## Issue Discipline

All implementation commits should reference GitHub issue #102. Use the branch `issue-102-omd-host-installer` and keep commits small enough to review independently.

## File Map

- Create `docs/superpowers/plans/2026-06-09-omd-host-installer-issue-102.md`: this implementation plan.
- Create `install/bootstrap.sh`: first-run `curl | bash` bootstrapper.
- Create `tests/test-bootstrap.sh`: shell tests for Ubuntu 24.04 detection, release URL construction, local archive install, and no-run behavior.
- Create root `Cargo.toml`: Rust workspace definition.
- Create `crates/omd/Cargo.toml`: `omd` package metadata and dependencies.
- Create `crates/omd/src/main.rs`: CLI entrypoint, non-interactive commands, and TUI launch.
- Create `crates/omd/src/components.rs`: required/optional component catalog and selection behavior.
- Create `crates/omd/src/tui.rs`: minimal Ratatui/Crossterm TUI rendering and input loop.
- Create `modules/lib/common.sh`: shared shell dispatch and output helpers.
- Create `modules/core/brew.sh`, `modules/core/zsh.sh`, `modules/core/base-tools.sh`: required component modules.
- Create `modules/optional/claude-code.sh`, `modules/optional/codex.sh`, `modules/optional/opencode.sh`, `modules/optional/copilot.sh`, `modules/optional/gemini.sh`: optional component modules.
- Create `tests/test-module-contracts.sh`: lifecycle interface tests for every module.
- Modify `tests/run.sh`: include new bootstrap and module contract tests plus `cargo test` when Cargo is present.
- Modify `README.md` and `README_EN.md`: make `omd` host installer the primary path and mark Docker as legacy during migration.

---

### Task 1: Commit the issue-linked implementation plan

**Files:**
- Create: `docs/superpowers/plans/2026-06-09-omd-host-installer-issue-102.md`

- [ ] **Step 1: Verify the plan has no placeholder markers**

Run:

```bash
grep -nE '\b(TB[D]|TO[D]O|FIXM[E]|XX[X])\b' docs/superpowers/plans/2026-06-09-omd-host-installer-issue-102.md
```

Expected: command exits non-zero and prints nothing.

- [ ] **Step 2: Commit the plan**

Run:

```bash
git add docs/superpowers/plans/2026-06-09-omd-host-installer-issue-102.md
git commit -m "docs(installer): plan issue 102 omd migration" \
  -m "Refs #102\n\nConstraint: Implementation must proceed issue-first from the approved omd host-installer design.\nConfidence: high\nScope-risk: narrow\nTested: grep placeholder scan\nNot-tested: Runtime behavior; planning-only change"
```

Expected: one commit with the plan file.

---

### Task 2: Add bootstrap tests first

**Files:**
- Create: `tests/test-bootstrap.sh`
- Modify later: `install/bootstrap.sh`

- [ ] **Step 1: Write failing bootstrap tests**

Create `tests/test-bootstrap.sh` with executable Bash tests that:

```bash
#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
bootstrap="${repo_root}/install/bootstrap.sh"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }

assert_eq() {
  local expected="$1" actual="$2"
  [[ "${actual}" == "${expected}" ]] || fail "expected '${expected}', got '${actual}'"
}

assert_file() { [[ -f "$1" ]] || fail "expected file: $1"; }
assert_executable() { [[ -x "$1" ]] || fail "expected executable: $1"; }

# shellcheck disable=SC1090
OHMYDEVPOD_BOOTSTRAP_LIB_ONLY=1 source "${bootstrap}"

ubuntu_release="${tmp_dir}/ubuntu-24.04"
cat > "${ubuntu_release}" <<'RELEASE'
ID=ubuntu
VERSION_ID="24.04"
RELEASE

assert_eq "ubuntu-24.04" "$(omd_detect_os_release "${ubuntu_release}")"
assert_eq "omd-x86_64-unknown-linux-gnu.tar.gz" "$(omd_archive_name x86_64-unknown-linux-gnu)"
assert_eq "https://github.com/zhangdw156/oh-my-devpod/releases/latest/download/omd-x86_64-unknown-linux-gnu.tar.gz" "$(omd_release_url latest x86_64-unknown-linux-gnu)"

bad_release="${tmp_dir}/debian"
cat > "${bad_release}" <<'RELEASE'
ID=debian
VERSION_ID="12"
RELEASE
if omd_detect_os_release "${bad_release}" >/dev/null 2>&1; then
  fail "debian should be rejected"
fi

archive_root="${tmp_dir}/archive"
mkdir -p "${archive_root}"
printf '#!/usr/bin/env bash\necho omd-test\n' > "${archive_root}/omd"
chmod +x "${archive_root}/omd"
tar -czf "${tmp_dir}/omd.tar.gz" -C "${archive_root}" omd

bin_dir="${tmp_dir}/bin"
omd_install_archive "${tmp_dir}/omd.tar.gz" "${bin_dir}"
assert_executable "${bin_dir}/omd"
assert_eq "omd-test" "$(${bin_dir}/omd)"

OHMYDEVPOD_BOOTSTRAP_NO_RUN=1 \
OHMYDEVPOD_SKIP_SUDO_CHECK=1 \
OHMYDEVPOD_OS_RELEASE="${ubuntu_release}" \
OHMYDEVPOD_OMD_ARCHIVE="${tmp_dir}/omd.tar.gz" \
OHMYDEVPOD_BIN_DIR="${tmp_dir}/bin2" \
bash "${bootstrap}"
assert_file "${tmp_dir}/bin2/omd"
```

- [ ] **Step 2: Run the test and verify RED**

Run:

```bash
bash tests/test-bootstrap.sh
```

Expected: FAIL because `install/bootstrap.sh` does not exist or does not expose the tested functions.

---

### Task 3: Implement bootstrap minimally

**Files:**
- Create: `install/bootstrap.sh`
- Test: `tests/test-bootstrap.sh`

- [ ] **Step 1: Implement `install/bootstrap.sh`**

Add a Bash script that defines:

- `omd_detect_os_release <file>`: accepts only `ID=ubuntu` and `VERSION_ID=24.04`.
- `omd_target_triple`: maps `x86_64`/`amd64` to `x86_64-unknown-linux-gnu` and `aarch64`/`arm64` to `aarch64-unknown-linux-gnu`.
- `omd_archive_name <target>`: prints `omd-<target>.tar.gz`.
- `omd_release_url <version> <target>`: prints the GitHub Release download URL.
- `omd_install_archive <archive> <bin_dir>`: extracts an executable `omd` into `<bin_dir>`.
- `omd_main`: validates platform, sudo, downloads or uses `OHMYDEVPOD_OMD_ARCHIVE`, installs `omd`, and launches it unless `OHMYDEVPOD_BOOTSTRAP_NO_RUN=1`.

The script must stop before `omd_main` when `OHMYDEVPOD_BOOTSTRAP_LIB_ONLY=1`.

- [ ] **Step 2: Run bootstrap test and verify GREEN**

Run:

```bash
bash tests/test-bootstrap.sh
```

Expected: PASS.

- [ ] **Step 3: Commit bootstrap work**

Run:

```bash
git add install/bootstrap.sh tests/test-bootstrap.sh
git commit -m "feat(installer): add issue 102 bootstrap entrypoint" \
  -m "Refs #102\n\nConstraint: curl entrypoint must stay small and testable before the Rust TUI is installed.\nConfidence: high\nScope-risk: moderate\nTested: bash tests/test-bootstrap.sh\nNot-tested: Live GitHub Release download; release artifact does not exist yet"
```

---

### Task 4: Add Rust `omd` tests first

**Files:**
- Create: `Cargo.toml`
- Create: `crates/omd/Cargo.toml`
- Create: `crates/omd/src/components.rs`
- Create: `crates/omd/src/main.rs`
- Create later: `crates/omd/src/tui.rs`

- [ ] **Step 1: Write initial Rust package and component tests**

Create the workspace and an `omd` package. In `crates/omd/src/components.rs`, write tests before implementation for:

```rust
#[test]
fn catalog_has_required_core_components() {
    let catalog = catalog();
    let required: Vec<_> = catalog.iter().filter(|c| c.required).map(|c| c.id).collect();
    assert_eq!(required, vec!["brew", "zsh", "base-tools"]);
}

#[test]
fn optional_components_start_unselected() {
    let state = SelectionState::new(catalog());
    assert!(!state.is_selected("claude-code"));
    assert!(!state.is_selected("codex"));
    assert!(!state.is_selected("opencode"));
    assert!(!state.is_selected("copilot"));
    assert!(!state.is_selected("gemini"));
}

#[test]
fn required_components_cannot_be_toggled_off() {
    let mut state = SelectionState::new(catalog());
    assert!(state.is_selected("brew"));
    assert_eq!(state.toggle("brew"), ToggleResult::RequiredUnchanged);
    assert!(state.is_selected("brew"));
}
```

- [ ] **Step 2: Run Rust tests and verify RED**

Run:

```bash
cargo test -p omd
```

Expected: FAIL because the component types and functions are not implemented.

---

### Task 5: Implement Rust `omd` skeleton

**Files:**
- Modify: `Cargo.toml`
- Modify: `crates/omd/Cargo.toml`
- Modify: `crates/omd/src/components.rs`
- Modify: `crates/omd/src/main.rs`
- Create: `crates/omd/src/tui.rs`

- [ ] **Step 1: Implement component catalog and selection state**

Implement:

```rust
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Component {
    pub id: &'static str,
    pub name: &'static str,
    pub required: bool,
    pub module: &'static str,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ToggleResult {
    ToggledOn,
    ToggledOff,
    RequiredUnchanged,
    UnknownComponent,
}
```

Include required components `brew`, `zsh`, `base-tools` and optional components `claude-code`, `codex`, `opencode`, `copilot`, `gemini`.

- [ ] **Step 2: Implement CLI modes**

Implement `main.rs` so:

- `omd --version` prints `omd <package version>`.
- `omd --dry-run` prints required and optional component IDs without launching the TUI.
- `omd --list-components` prints one line per component in the form `<id>\t<required|optional>\t<module>`.
- no arguments launch the TUI.

- [ ] **Step 3: Implement minimal Ratatui screen**

Implement `tui.rs` with a minimal event loop:

- renders title `oh-my-devpod installer (omd)`,
- renders required and optional component lists,
- allows `q` or `Esc` to exit,
- allows arrow keys to move selection,
- allows space to toggle only optional components.

- [ ] **Step 4: Run Rust tests and CLI smoke checks**

Run:

```bash
cargo test -p omd
cargo run -p omd -- --version
cargo run -p omd -- --dry-run
cargo run -p omd -- --list-components
```

Expected: tests pass and each command exits 0.

- [ ] **Step 5: Commit Rust skeleton**

Run:

```bash
git add Cargo.toml crates/omd
git commit -m "feat(installer): add issue 102 omd tui skeleton" \
  -m "Refs #102\n\nConstraint: Bootstrap downloads a prebuilt Rust binary, so the binary must expose non-interactive checks for CI.\nConfidence: medium\nScope-risk: moderate\nTested: cargo test -p omd; cargo run -p omd -- --version; cargo run -p omd -- --dry-run; cargo run -p omd -- --list-components\nNot-tested: Interactive terminal rendering beyond compile-time coverage"
```

---

### Task 6: Add shell module contract tests first

**Files:**
- Create: `tests/test-module-contracts.sh`
- Create later: `modules/lib/common.sh`
- Create later: module files under `modules/core/` and `modules/optional/`

- [ ] **Step 1: Write failing module contract test**

Create `tests/test-module-contracts.sh` that iterates these modules:

```bash
modules/core/brew.sh
modules/core/zsh.sh
modules/core/base-tools.sh
modules/optional/claude-code.sh
modules/optional/codex.sh
modules/optional/opencode.sh
modules/optional/copilot.sh
modules/optional/gemini.sh
```

For each module, assert:

- file exists,
- file is executable,
- `status` exits 0 or 1 but not 2,
- `install --dry-run` exits 0,
- `update --dry-run` exits 0,
- `uninstall --dry-run` exits 0 for optional modules,
- `uninstall --dry-run` exits non-zero for required modules,
- unknown actions exit non-zero.

- [ ] **Step 2: Run module contract test and verify RED**

Run:

```bash
bash tests/test-module-contracts.sh
```

Expected: FAIL because `modules/` does not exist.

---

### Task 7: Implement shell module contracts

**Files:**
- Create: `modules/lib/common.sh`
- Create: `modules/core/brew.sh`
- Create: `modules/core/zsh.sh`
- Create: `modules/core/base-tools.sh`
- Create: `modules/optional/claude-code.sh`
- Create: `modules/optional/codex.sh`
- Create: `modules/optional/opencode.sh`
- Create: `modules/optional/copilot.sh`
- Create: `modules/optional/gemini.sh`
- Test: `tests/test-module-contracts.sh`

- [ ] **Step 1: Implement shared module helper**

`modules/lib/common.sh` should define:

- `omd_module_info <level> <message>` for predictable output.
- `omd_module_has_flag --dry-run "$@"`.
- `omd_module_required_uninstall <name>` that exits non-zero and explains required modules cannot be uninstalled.
- `omd_module_unknown_action <action>` that exits non-zero.

- [ ] **Step 2: Implement required modules**

Required modules should support dry-run actions and reject uninstall. Initial install/update commands may delegate to existing scripts or print planned brew operations in dry-run mode. They must not delete user data.

- [ ] **Step 3: Implement optional modules**

Optional modules should support dry-run install/update/uninstall and perform safe uninstall only for software bodies when not in dry-run. Configuration directories such as `~/.claude`, `~/.codex`, and provider auth caches must not be removed.

- [ ] **Step 4: Run module contract test and verify GREEN**

Run:

```bash
bash tests/test-module-contracts.sh
```

Expected: PASS.

- [ ] **Step 5: Commit modules**

Run:

```bash
git add modules tests/test-module-contracts.sh
git commit -m "feat(installer): add issue 102 module contracts" \
  -m "Refs #102\n\nConstraint: Rust TUI must orchestrate stable shell lifecycle actions without owning tool-specific package logic.\nConfidence: medium\nScope-risk: moderate\nTested: bash tests/test-module-contracts.sh\nNot-tested: Live installation of external AI CLIs"
```

---

### Task 8: Wire tests and documentation

**Files:**
- Modify: `tests/run.sh`
- Modify: `README.md`
- Modify: `README_EN.md`

- [ ] **Step 1: Update test runner**

Add the new tests near the top of `tests/run.sh`:

```bash
bash "${repo_root}/tests/test-bootstrap.sh"
bash "${repo_root}/tests/test-module-contracts.sh"
if command -v cargo >/dev/null 2>&1; then
  (cd "${repo_root}" && cargo test -p omd)
fi
```

- [ ] **Step 2: Update README primary flow**

Make `curl -fsSL .../install/bootstrap.sh | bash` and `omd` the first documented path. Keep Docker language clearly marked as legacy during migration.

- [ ] **Step 3: Run full validation**

Run:

```bash
bash tests/run.sh
cargo test -p omd
git diff --check
```

Expected: all commands pass.

- [ ] **Step 4: Commit docs/test wiring**

Run:

```bash
git add tests/run.sh README.md README_EN.md
git commit -m "docs(installer): promote issue 102 omd flow" \
  -m "Refs #102\n\nConstraint: Host installer is now the primary product direction while Docker remains legacy until removal stage.\nConfidence: medium\nScope-risk: moderate\nTested: bash tests/run.sh; cargo test -p omd; git diff --check\nNot-tested: Live curl bootstrap against a published release"
```

---

### Task 9: Final verification and issue update

**Files:**
- No required file changes.

- [ ] **Step 1: Inspect branch state**

Run:

```bash
git status --short --branch
git log --oneline --decorate -6
```

Expected: clean working tree on `issue-102-omd-host-installer`.

- [ ] **Step 2: Post issue progress comment**

Run:

```bash
gh issue comment 102 --body "Implemented the first issue-driven host-installer slice on branch \`issue-102-omd-host-installer\`: bootstrap tests/path, Rust \`omd\` TUI skeleton, shell module contracts, and README migration wording. Verification: \`bash tests/run.sh\`, \`cargo test -p omd\`, \`git diff --check\`."
```

Expected: issue #102 receives a progress comment.
