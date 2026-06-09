<p align="center">
  <img src="https://img.shields.io/badge/Ubuntu-24.04-E95420?style=for-the-badge&logo=ubuntu&logoColor=white" alt="Ubuntu 24.04"/>
  <img src="https://img.shields.io/badge/Rust_TUI_Host_Installer-2496ED?style=for-the-badge" alt="Rust TUI Host Installer"/>
  <img src="https://img.shields.io/badge/Zsh-Powerlevel10k-4EAA25?style=for-the-badge&logo=gnubash&logoColor=white" alt="Zsh"/>
  <img src="https://img.shields.io/github/v/tag/zhangdw156/oh-my-devpod?style=for-the-badge&label=version&color=blue" alt="Version"/>
</p>

<h1 align="center">oh-my-devpod</h1>

<p align="center">
  <strong>One curl entrypoint, one Rust TUI installer</strong><br/>
  Install and manage AI development tooling directly on Ubuntu 24.04 hosts.
</p>

<p align="center">
  English | <a href="./README.md">中文</a>
</p>

---

## One-line `omd` Installer

oh-my-devpod is migrating to an **Ubuntu 24.04 host installer**. First run:

```bash
curl -fsSL https://raw.githubusercontent.com/zhangdw156/oh-my-devpod/main/install/bootstrap.sh | bash
```

The bootstrap script only:

1. verifies Ubuntu 24.04,
2. checks `sudo` and may prompt for the sudo password,
3. downloads the prebuilt Rust TUI binary from GitHub Releases,
4. installs it to `~/.local/bin/omd`,
5. launches `omd`.

Repeat runs use the long-lived command:

```bash
omd
```

The same TUI handles first-time install, updates, add-on installs, and optional component uninstall.

## Install Model

`omd` manages two component classes:

- **Required**: Homebrew, zsh environment, and baseline development tools.
- **Optional**: Claude Code, Codex CLI, OpenCode, GitHub Copilot CLI, and Gemini CLI.

Optional uninstall removes only the software body, wrappers, symlinks, or oh-my-devpod-managed package prefix. It does not delete user config, caches, auth state, tokens, or login sessions.

Default user-level paths:

```text
~/.local/bin/omd
~/.local/share/oh-my-devpod/
~/.local/state/oh-my-devpod/logs/
~/.cache/oh-my-devpod/
```

## Current Implementation Status

- `install/bootstrap.sh` is the new `curl | bash` entrypoint.
- `crates/omd/` is the Rust + Ratatui + Crossterm TUI.
- `modules/` exposes the `status` / `install` / `update` / `uninstall` lifecycle interface.
- The old `install/setup.sh` remains temporarily as a migration compatibility script.

## Legacy Docker Usage

Docker / multi-flavor images remain in the repository as a legacy path, but they are no longer the new primary product direction. Image versions are still managed by the repository-root `VERSION` file, and compose still supports `IMAGE_VERSION` overrides.



### Pull and use official images

```bash
docker pull ghcr.io/zhangdw156/claudepod:latest
docker run --rm -it --network host --user "$(id -u):$(id -g)" -v "$PWD:/workspace" -w /workspace ghcr.io/zhangdw156/claudepod:latest
```

Other flavors:

```bash
docker run --rm -it --network host --user "$(id -u):$(id -g)" -v "$PWD:/workspace" -w /workspace ghcr.io/zhangdw156/openpod:latest
docker run --rm -it --network host --user "$(id -u):$(id -g)" -v "$PWD:/workspace" -w /workspace ghcr.io/zhangdw156/codexpod:latest
docker run --rm -it --network host --user "$(id -u):$(id -g)" -v "$PWD:/workspace" -w /workspace ghcr.io/zhangdw156/copilotpod:latest
docker run --rm -it --network host --user "$(id -u):$(id -g)" -v "$PWD:/workspace" -w /workspace ghcr.io/zhangdw156/geminipod:latest
```

> **Note:** Always include `--user "$(id -u):$(id -g)"` to run the container as your host user. Without it, the container runs as root and changes file ownership under the mounted workspace, making them inaccessible on the host.

Direct command examples:

```bash
docker run --rm --network host --user "$(id -u):$(id -g)" -v "$PWD:/workspace" -w /workspace ghcr.io/zhangdw156/openpod:latest opencode --version
docker run --rm --network host --user "$(id -u):$(id -g)" -v "$PWD:/workspace" -w /workspace ghcr.io/zhangdw156/claudepod:latest claude --version
docker run --rm --network host --user "$(id -u):$(id -g)" -v "$PWD:/workspace" -w /workspace ghcr.io/zhangdw156/codexpod:latest codex --help
docker run --rm --network host --user "$(id -u):$(id -g)" -v "$PWD:/workspace" -w /workspace ghcr.io/zhangdw156/copilotpod:latest copilot --version
docker run --rm --network host --user "$(id -u):$(id -g)" -v "$PWD:/workspace" -w /workspace ghcr.io/zhangdw156/geminipod:latest gemini --version
```

### Run with compose

```bash
docker compose -f docker/claudepod/docker-compose.yaml run --rm -it claudepod
docker compose -f docker/openpod/docker-compose.yaml run --rm -it openpod
docker compose -f docker/codexpod/docker-compose.yaml run --rm -it codexpod
docker compose -f docker/copilotpod/docker-compose.yaml run --rm -it copilotpod
docker compose -f docker/geminipod/docker-compose.yaml run --rm -it geminipod
```

Compose files pull from `ghcr.io/zhangdw156/{flavor}:latest` by default. Image versions are managed by the `VERSION` file at the repository root. To pin a version:

```bash
IMAGE_VERSION=0.10.0 docker compose -f docker/claudepod/docker-compose.yaml run --rm -it claudepod
```

### Build images locally

If you need to customize the images, build directly from the Dockerfiles:

```bash
docker build -f Dockerfile.devpod -t devpod:local .
docker build -f docker/openpod/Dockerfile --build-arg DEVPOD_BASE_IMAGE=devpod:local -t openpod:local .
docker build -f docker/claudepod/Dockerfile --build-arg DEVPOD_BASE_IMAGE=devpod:local -t claudepod:local .
docker build -f docker/codexpod/Dockerfile --build-arg DEVPOD_BASE_IMAGE=devpod:local -t codexpod:local .
docker build -f docker/copilotpod/Dockerfile --build-arg DEVPOD_BASE_IMAGE=devpod:local -t copilotpod:local .
docker build -f docker/geminipod/Dockerfile --build-arg DEVPOD_BASE_IMAGE=devpod:local -t geminipod:local .
```

Alternatively, uncomment the `build:` section in the compose files to build via compose.

## Repository Layout

```text
oh-my-devpod/
├── install/
│   └── bootstrap.sh
├── crates/
│   └── omd/
├── modules/
│   ├── core/
│   └── optional/
├── Dockerfile.devpod
├── docker/
│   ├── openpod/
│   │   ├── Dockerfile
│   │   └── docker-compose.yaml
│   ├── claudepod/
│   │   ├── Dockerfile
│   │   └── docker-compose.yaml
│   ├── codexpod/
│   │   ├── Dockerfile
│   │   └── docker-compose.yaml
│   ├── copilotpod/
│   │   ├── Dockerfile
│   │   └── docker-compose.yaml
│   └── geminipod/
│       ├── Dockerfile
│       └── docker-compose.yaml
├── runtime/
│   ├── openpod/
│   ├── claudepod/
│   ├── codexpod/
│   ├── copilotpod/
│   └── geminipod/
├── build/
├── config/
└── vendor/
```

## Verification

After development changes, start with:

```bash
bash tests/run.sh
cargo test -p omd
```

Legacy Docker smoke examples:

```bash
docker run --rm --network host --user "$(id -u):$(id -g)" -v "$PWD:/workspace" -w /workspace ghcr.io/zhangdw156/openpod:latest opencode --version
docker run --rm --network host --user "$(id -u):$(id -g)" -v "$PWD:/workspace" -w /workspace ghcr.io/zhangdw156/claudepod:latest claude --version
docker run --rm --network host --user "$(id -u):$(id -g)" -v "$PWD:/workspace" -w /workspace ghcr.io/zhangdw156/codexpod:latest codex --help | head -1
docker run --rm --network host --user "$(id -u):$(id -g)" -v "$PWD:/workspace" -w /workspace ghcr.io/zhangdw156/copilotpod:latest copilot --version
docker run --rm --network host --user "$(id -u):$(id -g)" -v "$PWD:/workspace" -w /workspace ghcr.io/zhangdw156/geminipod:latest gemini --version
```

## Notes

- `omd` is the new primary entrypoint; `curl | bash` only installs and starts it
- `devpod` / multi-flavor images are legacy until migration is complete
- legacy `openpod`, `claudepod`, `codexpod`, `copilotpod`, and `geminipod` still share one version number
- The first `nvim` launch still needs network access because `lazy.nvim` downloads plugins on demand
