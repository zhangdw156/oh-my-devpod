# Environment Variables Reference

## Bootstrap

| Variable | Default | Purpose |
| --- | --- | --- |
| `OHMYDEVPOD_SOURCE` | `auto` | `auto`, `github`, or `gitee` release source |
| `OHMYDEVPOD_VERSION` | `latest` | Release version |
| `OHMYDEVPOD_BIN_DIR` | `~/.local/bin` | Active `omd` symlink directory |
| `OHMYDEVPOD_PREFIX` | `~/.local/share/oh-my-devpod` | Versioned releases and managed tools |
| `OHMYDEVPOD_CACHE_DIR` | `~/.cache/oh-my-devpod` | Download cache |
| `OHMYDEVPOD_CONFIG_DIR` | `~/.config/oh-my-devpod` | Persisted source and mirror profile |
| `OHMYDEVPOD_OS_RELEASE` | `/etc/os-release` | Platform-detection test override |
| `OHMYDEVPOD_OMD_ARCHIVE` | empty | Local release archive override |
| `OHMYDEVPOD_OMD_CHECKSUM` | empty | Local checksum override |
| `OHMYDEVPOD_BOOTSTRAP_NO_RUN` | `0` | Install without launching the TUI |
| `OHMYDEVPOD_BOOTSTRAP_LIB_ONLY` | `0` | Source helper functions only |

## Runtime

| Variable | Default | Purpose |
| --- | --- | --- |
| `OHMYDEVPOD_BUNDLE_ROOT` | executable-relative | Bundle root override for development/tests |
| `OHMYDEVPOD_STATE_DIR` | `~/.local/state/oh-my-devpod` | Logs, locks, and ownership markers |
| `OHMYDEVPOD_MIRROR_PROFILE` | persisted profile | `upstream` or `cn` |

The `cn` profile exports:

```text
HOMEBREW_BREW_GIT_REMOTE=https://mirrors.ustc.edu.cn/brew.git
HOMEBREW_BOTTLE_DOMAIN=https://mirrors.ustc.edu.cn/homebrew-bottles
HOMEBREW_API_DOMAIN=https://mirrors.ustc.edu.cn/homebrew-bottles/api
UV_CONFIG_FILE=~/.config/oh-my-devpod/uv.toml
```

The managed uv configuration points its default index at the TUNA PyPI mirror.

## Module/test overrides

The module layer supports path overrides for isolated tests. Normal `omd`
execution supplies controlled values for the managed prefix, binary directory,
state directory, asset root, and component-specific installation paths.

Vendored tool versions remain centralized in `versions.env`.
