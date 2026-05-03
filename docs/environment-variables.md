# Environment Variables Reference

All `OHMYDEVPOD_*` environment variables used by the project.

## Build-Time Variables

These are consumed during `docker build` or by install scripts. They are not guaranteed to be available at container runtime.

| Variable | Default | Used By | Purpose |
|----------|---------|---------|---------|
| `OHMYDEVPOD_ASSET_ROOT` | `/opt/vendor/releases` | `build/install-{btop,zellij,yazi,neovim,atuin}.sh` | Base path for vendored release archives |
| `OHMYDEVPOD_BIN_DIR` | `/usr/local/bin` | All install scripts | Directory for installed binaries |
| `OHMYDEVPOD_BTOP_DIR` | `/opt/btop` | `build/install-btop.sh` | btop installation directory |
| `OHMYDEVPOD_ANTIDOTE_DIR` | `/opt/antidote` | `build/install-antidote.sh` | Antidote (zsh plugin manager) install directory |
| `OHMYDEVPOD_NEOVIM_DIR` | `/opt/neovim` | `build/install-neovim.sh` | Neovim installation directory |
| `OHMYDEVPOD_UV_BIN` | `uv` | `build/install-python-dev-tools.sh` | Path to uv binary |
| `OHMYDEVPOD_UV_TOOL_DIR` | `/opt/uv-tools` | `build/install-python-dev-tools.sh` | Directory for uv-managed Python tools |
| `OHMYDEVPOD_LAZYVIM_SOURCE_DIR` | `/opt/vendor/nvim/lazyvim-starter` | `build/install-lazyvim.sh` | LazyVim starter snapshot source |
| `OHMYDEVPOD_NVM_OVERLAY_DIR` | *(empty)* | `build/install-lazyvim.sh` | Optional nvim config overlay directory |
| `OHMYDEVPOD_NVM_CONFIG_DIR` | `~/.config/nvim` | `build/install-lazyvim.sh` | Neovim config target directory |
| `OHMYDEVPOD_NVM_DATA_DIR` | `~/.local/share/nvim` | `build/install-lazyvim.sh` | Neovim data directory |
| `OHMYDEVPOD_NVM_STATE_DIR` | `~/.local/state/nvim` | `build/install-lazyvim.sh` | Neovim state directory |
| `OHMYDEVPOD_NVM_CACHE_DIR` | `~/.cache/nvim` | `build/install-lazyvim.sh` | Neovim cache directory |
| `OHMYDEVPOD_MANAGED_MARKER` | `.ohmydevpod-managed.json` | `build/install-lazyvim.sh` | Marker filename for managed nvim configs |
| `OHMYDEVPOD_CLAUDE_INSTALL_HOME` | `$HOME` | `build/install-claude-code.sh` | Home directory for Claude Code native install |
| `OHMYDEVPOD_CLAUDE_CODE_BUCKET_URL` | *(Google Cloud bucket)* | `build/install-claude-code.sh` | Claude Code release distribution URL |

## Runtime Metadata Variables

Set as `ENV` in Dockerfiles. Available inside running containers for version introspection.

| Variable | Example Value | Purpose |
|----------|---------------|---------|
| `OHMYDEVPOD_ATUIN_VERSION` | `v18.15.2` | Installed atuin version |
| `OHMYDEVPOD_HARLEQUIN_VERSION` | `2.5.2` | Installed harlequin version |
| `OHMYDEVPOD_PYRIGHT_VERSION` | `1.1.408` | Installed pyright version |
| `OHMYDEVPOD_RUFF_VERSION` | `0.15.9` | Installed ruff version |
| `OHMYDEVPOD_LAZYVIM_STARTER_COMMIT` | `803bc18...` | Pinned LazyVim starter commit |
| `OHMYDEVPOD_LAZYVIM_SOURCE_DIR` | `/opt/vendor/nvim/lazyvim-starter` | LazyVim source directory |
| `OHMYDEVPOD_NEOVIM_DIR` | `/opt/neovim` | Neovim installation root |
| `OHMYDEVPOD_UV_TOOL_DIR` | `/opt/uv-tools` | uv tool installation root |

## Flavor-Specific Variables

### Claude Code (claudepod)

| Variable | Default | Purpose |
|----------|---------|---------|
| `OHMYDEVPOD_CLAUDE_CODE_VERSION` | `2.1.92` | Claude Code version to install / installed version |
| `OHMYDEVPOD_CLAUDE_REAL_BIN` | `/usr/local/bin/claude-real` | Path to the actual Claude Code binary |
| `OHMYDEVPOD_REPO_ROOT` | `/opt` | Repository root for asset discovery |

### Codex (codexpod)

| Variable | Default | Purpose |
|----------|---------|---------|
| `OHMYDEVPOD_CODEX_VERSION` | `0.118.0` | Codex CLI version |
| `OHMYDEVPOD_CODEX_REAL_BIN` | `/usr/local/bin/codex-real` | Path to the actual Codex binary |

### Copilot (copilotpod)

| Variable | Default | Purpose |
|----------|---------|---------|
| `OHMYDEVPOD_COPILOT_VERSION` | `1.0.24` | Copilot CLI version |
| `OHMYDEVPOD_COPILOT_REAL_BIN` | `/usr/local/bin/copilot-real` | Path to the actual Copilot binary |

### Gemini (geminipod)

| Variable | Default | Purpose |
|----------|---------|---------|
| `OHMYDEVPOD_GEMINI_VERSION` | `0.37.1` | Gemini CLI version |
| `OHMYDEVPOD_GEMINI_REAL_BIN` | `/usr/local/bin/gemini-real` | Path to the actual Gemini binary |

### OpenCode (openpod)

| Variable | Default | Purpose |
|----------|---------|---------|
| `OHMYDEVPOD_OPENCODE_VERSION` | *(empty)* | OpenCode version (follows upstream image) |

## Harness Installation Variables

Used by `runtime/<flavor>/install-harness.sh` scripts during image build.

| Variable | Required | Purpose |
|----------|----------|---------|
| `OHMYDEVPOD_REPO_ROOT` | Yes | Repository root for locating runtime assets |
| `OHMYDEVPOD_PREFIX` | Yes (except claudepod) | Flavor-specific installation prefix |
| `OHMYDEVPOD_BIN_DIR` | Yes | Binary installation directory |
| `OHMYDEVPOD_CONFIG_HOME` | Yes | Configuration home for the harness |
| `OHMYDEVPOD_RUNTIME_VENDOR_HOME` | Yes (openpod only) | Path to runtime vendor assets |
| `OHMYDEVPOD_SHELL_DIR` | Yes (openpod only) | Shell launcher directory |

## Updating Versions

Tool versions are centralized in `versions.env` at the repository root. When updating a tool version:

1. Edit `versions.env` with the new version
2. Update the matching `ARG` default in the relevant Dockerfile
3. Update the matching fallback default in the relevant `build/install-*.sh` script
4. Run `bash tests/test-versions-env.sh` to verify consistency
