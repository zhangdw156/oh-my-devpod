# Environment Variables Reference

## Bootstrap

| Variable | Default | Purpose |
| --- | --- | --- |
| `OHMYDEVPOD_SOURCE` | `auto` | `auto`, `github`, or `gitee` release source |
| `OHMYDEVPOD_VERSION` | `latest` | Bootstrap or self-update release version |
| `OHMYDEVPOD_BIN_DIR` | `~/.local/bin` | Active `omd` symlink directory |
| `OHMYDEVPOD_PREFIX` | `~/.local/share/oh-my-devpod` | Versioned releases and managed tools |
| `OHMYDEVPOD_CACHE_DIR` | `~/.cache/oh-my-devpod` | Download cache |
| `OHMYDEVPOD_CONFIG_DIR` | `~/.config/oh-my-devpod` | Persisted source and mirror profile |
| `OHMYDEVPOD_OS_RELEASE` | `/etc/os-release` | Platform-detection test override |
| `OHMYDEVPOD_OMD_ARCHIVE` | empty | Local release archive override |
| `OHMYDEVPOD_OMD_CHECKSUM` | empty | Local checksum override |
| `OHMYDEVPOD_OMD_URL` | generated | Release archive URL override |
| `OHMYDEVPOD_OMD_CHECKSUM_URL` | generated | Release checksum URL override |
| `OHMYDEVPOD_BOOTSTRAP_NO_RUN` | `0` | Install without launching the TUI |
| `OHMYDEVPOD_BOOTSTRAP_LIB_ONLY` | `0` | Source helper functions only |

## Runtime

| Variable | Default | Purpose |
| --- | --- | --- |
| `OHMYDEVPOD_BUNDLE_ROOT` | executable-relative | Bundle root override for development/tests |
| `OHMYDEVPOD_STATE_DIR` | `~/.local/state/oh-my-devpod` | Logs, locks, and ownership markers |
| `OHMYDEVPOD_MIRROR_PROFILE` | persisted profile | `upstream` or `cn` |
| `OHMYDEVPOD_MAMBA_ROOT_PREFIX` | empty | Override the managed Micromamba root prefix |

Bootstrap also records the managed install prefix, binary directory, and cache
directory so later `omd --update` runs reuse the existing installation paths.

Managed shells default `MAMBA_ROOT_PREFIX` to
`${XDG_DATA_HOME:-$HOME/.local/share}/mamba`. An existing explicit
`MAMBA_ROOT_PREFIX` is preserved, while `OHMYDEVPOD_MAMBA_ROOT_PREFIX` provides
an OMD-specific override. Managed Zsh evaluates the Mamba shell hook so
`mamba activate` and `micromamba activate` can modify the current shell.
Managed Zsh configurations created before version 0.14.2 must be refreshed with
`omd --execute update zsh-config`, followed by a new shell.

OMD does not move or delete environments created under another root prefix.
Environments previously created inside a Homebrew Cellar must be exported and
recreated or migrated explicitly before that Cellar version is removed.

The `cn` profile exports:

```text
HOMEBREW_BREW_GIT_REMOTE=https://mirrors.ustc.edu.cn/brew.git
HOMEBREW_BOTTLE_DOMAIN=https://mirrors.ustc.edu.cn/homebrew-bottles
HOMEBREW_API_DOMAIN=https://mirrors.ustc.edu.cn/homebrew-bottles/api
UV_CONFIG_FILE=~/.config/oh-my-devpod/uv.toml
PIP_INDEX_URL=https://mirrors.tuna.tsinghua.edu.cn/pypi/web/simple
CONDA_CHANNELS=conda-forge
MAMBA_CHANNEL_ALIAS=https://mirrors.tuna.tsinghua.edu.cn/anaconda/cloud
MAMBA_DEFAULT_CHANNELS=https://mirrors.tuna.tsinghua.edu.cn/anaconda/pkgs/main,...
```

The managed uv configuration and `PIP_INDEX_URL` point Python package downloads
at the TUNA PyPI mirror. `CONDA_CHANNELS` makes `conda-forge` the default
Micromamba channel, while the Mamba channel settings route named and `defaults`
channels through TUNA. These variables are inherited by pip and Micromamba
commands launched from the managed shell, including pip inside Micromamba
environments. OMD does not write or replace user-owned Conda, Mamba, or pip
configuration files.

The managed source variables intentionally take precedence over user package
source settings while the `cn` profile is active. An explicit source switch
updates OMD subprocesses immediately; an already-running interactive shell must
start a new shell or re-source
`${OHMYDEVPOD_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/oh-my-devpod}/env`
to receive the new values.

## Module/test overrides

The module layer supports path overrides for isolated tests. Normal `omd`
execution supplies controlled values for the managed prefix, binary directory,
state directory, asset root, and component-specific installation paths.

Vendored tool versions remain centralized in `versions.env`.
