# Environment Variables Reference

All `OHMYDEVPOD_*` environment variables used by the host installer and reusable install scripts.

## Bootstrap Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `OHMYDEVPOD_VERSION` | `latest` | Release version used by `install/bootstrap.sh` when constructing the `omd` archive URL |
| `OHMYDEVPOD_BIN_DIR` | `~/.local/bin` | User-level directory for installing `omd` and managed command symlinks |
| `OHMYDEVPOD_CACHE_DIR` | `~/.cache/oh-my-devpod` | Bootstrap download cache |
| `OHMYDEVPOD_OS_RELEASE` | `/etc/os-release` | Test override for Ubuntu 24.04 detection |
| `OHMYDEVPOD_OMD_ARCHIVE` | *(empty)* | Local `omd` archive path used by tests or offline bootstrap flows |
| `OHMYDEVPOD_OMD_URL` | GitHub Release URL | Explicit `omd` archive URL override |
| `OHMYDEVPOD_BOOTSTRAP_NO_RUN` | `0` | Install `omd` but do not launch it when set to `1` |
| `OHMYDEVPOD_BOOTSTRAP_LIB_ONLY` | `0` | Source bootstrap helper functions without running main when set to `1` |
| `OHMYDEVPOD_SKIP_SUDO_CHECK` | `0` | Test override for skipping interactive sudo validation |

## Module Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `OHMYDEVPOD_PREFIX` | `~/.local/share/oh-my-devpod` | Managed package prefix for optional components |
| `OHMYDEVPOD_BIN_DIR` | `~/.local/bin` | Managed command symlink directory |
| `OHMYDEVPOD_CLAUDE_INSTALL_HOME` | `$HOME` | Home directory for Claude Code native install |
| `OHMYDEVPOD_CLAUDE_CODE_BUCKET_URL` | Claude Code release bucket | Claude Code release distribution URL |
| `OHMYDEVPOD_CLAUDE_CODE_VERSION` | `versions.env` fallback | Claude Code version override |
| `OHMYDEVPOD_CODEX_VERSION` | `versions.env` fallback | Codex CLI version override |
| `OHMYDEVPOD_COPILOT_VERSION` | `versions.env` fallback | GitHub Copilot CLI version override |
| `OHMYDEVPOD_GEMINI_VERSION` | `versions.env` fallback | Gemini CLI version override |
| `OHMYDEVPOD_OPENCODE_VERSION` | *(empty)* | OpenCode package version override |

## Build Script Variables

| Variable | Default | Used By | Purpose |
|----------|---------|---------|---------|
| `OHMYDEVPOD_ASSET_ROOT` | `/opt/vendor/releases` | `build/install-{btop,zellij,yazi,neovim,atuin,witr}.sh` | Base path for vendored release archives |
| `OHMYDEVPOD_BTOP_DIR` | `/opt/btop` | `build/install-btop.sh` | btop installation directory |
| `OHMYDEVPOD_ANTIDOTE_DIR` | `/opt/antidote` | `build/install-antidote.sh` | Antidote installation directory |
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

## Updating Versions

Tool versions are centralized in `versions.env` at the repository root. When updating a tool version:

1. Edit `versions.env` with the new version.
2. Update the matching fallback default in the relevant `build/install-*.sh` script.
3. Run `bash tests/test-versions-env.sh` to verify consistency.
4. Run `bash tests/run.sh` and `cargo test -p omd` before committing.
