# OMD user guide

[Project home](../README.md) · [简体中文](guide.zh-CN.md)

## Prerequisites

OMD supports Ubuntu 20.04, 22.04, 24.04, and 26.04 on x86_64. On a fresh host, an administrator installs the system packages Linuxbrew needs once per machine.

```bash
sudo apt-get update
sudo apt-get install -y build-essential procps curl file git ca-certificates
```

On 20.04 and 22.04, install `python3-distutils` if you explicitly use the system interpreter with `uv venv --python /usr/bin/python3`.

## Install

Run one of the following installers from your own account. The bootstrap downloads the release, verifies its SHA256 checksum, installs `~/.local/bin/omd`, and opens the TUI. Run `omd` to reopen it. If the bin directory is new, use `~/.local/bin/omd` in the current terminal.

**GitHub**

The default tries GitHub first and falls back to Gitee if it cannot download a verified release.

```bash
curl -fsSL https://raw.githubusercontent.com/zhangdw156/oh-my-devpod/main/install/bootstrap.sh | bash
```

**Gitee**

This selects the China mirror profile during installation.

```bash
curl -fsSL https://gitee.com/zhangdw156/oh-my-devpod/raw/main/install/bootstrap.sh \
  | OHMYDEVPOD_SOURCE=gitee bash
```

**npm**

With Node.js 18 or later and a user-writable global npm prefix, choose one installation command. Then run `omd`.

```bash
npm install --global oh-my-devpod
```

```bash
OHMYDEVPOD_SOURCE=gitee npm install --global oh-my-devpod
```

The npm package includes the runtime bundle. `OHMYDEVPOD_SOURCE` selects where OMD gets components. npm uses its configured registry to fetch the package.

### Networks limited to domestic mirrors

Use a reachable Ubuntu APT mirror. The Gitee profile gets OMD releases from Gitee, Homebrew Git repositories, API data and bottles from USTC, PyPI and Conda packages from TUNA, and uv-managed Python interpreters from npmmirror. The bundled LazyVim plugins work offline. `gh` login and GitHub PR operations still need GitHub connectivity. User-added editor plugins, external tools and Git remotes use their own configured sources. [Offline editor details](vendor-assets.md#lazyvim-in-the-china-profile)

## TUI and CLI

Run `omd`. Under Linuxbrew, expand Neovim to find LazyVim, or Zsh to find its productivity configuration. Each row has its own selection and state. Selecting LazyVim adds both Git and Neovim to an install plan when missing. Search matches by name, ID, category or description and expands the matching rows’ ancestors.

| Key | Action |
| --- | --- |
| `Tab` | Cycle install, update and uninstall. Changing action clears the selection. |
| `↓` / `j`, `↑` / `k` | Move down or up. |
| `→` / `l`, `←` / `h` | Expand or collapse a branch. Left on a leaf or collapsed row moves to its parent. |
| `/` | Type a filter. `Backspace` edits it, `Enter` keeps it and `Esc` clears it. |
| `Space` | Select or deselect the current component. |
| `Enter` | Open the plan. Press again on a valid plan to execute. |
| `Esc` | Return from the plan, clear the active filter or leave the list. |
| `q` | Quit from the list or plan. |

CLI commands accept component IDs from the catalog. Inspection and planning are read-only.

| Command | Result |
| --- | --- |
| `omd --list-components` | List IDs, dependency types, scope and uninstall support. |
| `omd --status` | Show which components are missing, externally installed, managed or in need of repair. |
| `omd --version` | Print the active OMD version. |
| `omd --plan install micromamba lazyvim` | Show installation order assuming a fresh account. |
| `omd --plan-current uninstall lazyvim neovim` | Preview removal against the current account’s inventory. |
| `omd --dry-run` | Preview installing the whole catalog, including the module actions. |
| `omd --execute install ripgrep fzf` | Install the selected tools and their missing dependencies. |
| `omd --execute update zsh-config` | Refresh the installed managed Zsh configuration. |

An install orders dependencies first. An uninstall orders dependants first and blocks removal if a remaining installed component needs the target. OMD checks the plan again under an execution lock before it starts running modules.

## Switch sources

| Command | When to use it |
| --- | --- |
| `omd --source gitee` | Use China mirrors for managed tools and future component operations. Works with both installation channels. |
| `omd --source github` | Return those tools and future operations to upstream sources. |
| `omd --update` | Update a bootstrap installation from its saved release source in `~/.config/oh-my-devpod/source`. An absent or invalid source defaults to GitHub. |
| `omd --update --gitee` | Update from Gitee and select China mirrors, even when the version is already current. |
| `omd --update --github` | Update from GitHub and select upstream sources, even when the version is already current. |

Choose one source per operation. Switching immediately affects OMD subprocesses. Open a new managed shell to pick up the change, or refresh the running shell with `source "${OHMYDEVPOD_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/oh-my-devpod}/env"`.

OMD updates the relevant native settings for tools it manages. Linuxbrew uses the `brew` and `homebrew/core` remotes and `~/.linuxbrew/etc/homebrew/brew.env`. uv uses `~/.config/uv/uv.toml`, Micromamba uses `~/.mambarc`, and pip uses `~/.config/pip/pip.conf` with the default XDG paths. Switching back removes OMD-generated mirror settings. A conflict with an existing user file or an edited managed file stops the switch and restores the previous profile. Installed packages and environments stay in place. [Configuration paths and environment variables](environment-variables.md)

## Update

For a bootstrap installation, run `omd --update`. Only the OMD release bundle is replaced. Downloads and bundle contents must pass validation before activation. A failed download, validation or activation preserves the active installation and its source profile. [Update from a different source](#switch-sources)

For an npm installation, run `npm update --global oh-my-devpod`. `omd --update` directs npm users to this command. npm retains the selected component source across updates. To update individual tools, choose **update** in the TUI or use `omd --execute update` with the component IDs.

### Upgrading older installations

- If 0.14.1 reports `previous_dir: unbound variable`, the candidate may already be active. Check `omd --version`, then run `omd --update` once more. From 0.14.4 onward the verified candidate bootstrap handles activation.
- When upgrading a managed Zsh configuration from 0.14.1 or earlier, run `omd --execute update zsh-config` and open a new shell.
- If an older installer rejects the current archive, rerun the current bootstrap as your own user, then install your personal Linuxbrew. [Installation commands](#install)

## Shared servers

Each account installs its own OMD. Choose Linuxbrew in the TUI or run `omd --execute install linuxbrew`. Bash and Zsh pick up its binaries on the next login. A formula already in the account’s Cellar can satisfy dependencies while remaining externally owned. An administrator’s system-wide Brew stays under its existing owner. Bottles that require Homebrew’s standard Linux prefix may need to build from source under `~/.linuxbrew`.

| Default path | Contents |
| --- | --- |
| `~/.linuxbrew/` | Personal Brew executable, Cellar and mirror settings |
| `~/.local/bin/omd` | Active bootstrap launcher |
| `~/.local/share/oh-my-devpod/releases/<version>/` | Versioned bootstrap bundle |
| `~/.local/share/oh-my-devpod/zsh/` | Managed Zsh assets |
| `~/.local/state/oh-my-devpod/` | Component ownership markers, execution lock and configuration backups |
| `~/.config/oh-my-devpod/` | Saved release source, installation paths and shell environment |
| `~/.cache/oh-my-devpod/` | Downloaded release archives |

### SSH and managed Zsh

If Zsh and its configuration were already managed before upgrading OMD, run `omd --execute update zsh-config` once to install the new login hook.

With OMD-managed Zsh and `zsh-config` installed, a new interactive SSH login through Bash starts `~/.linuxbrew/bin/zsh` and loads the managed `~/.zshrc`. Remote commands and file transfers keep their usual shell. `echo "$ZSH_VERSION"` identifies the running Zsh. `$SHELL` reports the account’s configured login shell, which can still be `/bin/bash`. To enter Zsh immediately, run `exec "$HOME/.linuxbrew/bin/zsh" -l`.

OMD adds a hook to the first applicable Bash login profile (`.bash_profile`, `.bash_login` or `.profile`) and removes it when uninstalling the configuration. It skips linked or unowned startup files. The managed `~/.zshenv` line lets Oh My Zsh initialize trusted completions after excluding insecure paths. The `z` command jumps to frequently visited directories. The Mamba hook respects `MAMBA_ROOT_PREFIX`, including the versioned Cellar root chosen by Homebrew-installed Mamba.

Managed Zsh preserves `EDITOR` and `VISUAL` and defaults both to `nvim` when neither is set and Neovim is available. `zj` appears with Zellij. With Yazi installed, `y` changes the shell’s directory to the last location you browsed. `dust` is an independent optional component. Install it to inspect a tree with `dust .`.

### Uninstall and personal data

OMD requires a matching ownership marker to remove a component and protects Linuxbrew from normal uninstall. It backs up pre-existing Zsh and Neovim configurations before replacing them. LazyVim removal preserves its configuration backup, editor data, state and caches. The Gitee CLI component installs the official SHA256-verified release in `~/.local/bin/gitee`. Updating or uninstalling it preserves `~/.config/gitee`, a custom `GITEE_CONFIG_DIR`, Agent Skills and login state.
