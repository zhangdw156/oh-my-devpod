<h1 align="center">oh-my-devpod</h1>

<p align="center">
  <strong>One curl entry point and one dependency-aware Linux productivity tool manager.</strong><br/>
  Select, install, update, and safely uninstall development tools on Ubuntu 24.04.
</p>

<p align="center">
  English | <a href="./README.md">中文</a>
</p>

## Quick start

GitHub:

```bash
curl -fsSL https://raw.githubusercontent.com/zhangdw156/oh-my-devpod/main/install/bootstrap.sh | bash
```

Gitee with China mirrors:

```bash
curl -fsSL https://gitee.com/zhangdw156/oh-my-devpod/raw/main/install/bootstrap.sh \
  | OHMYDEVPOD_SOURCE=gitee bash
```

The bootstrap downloads a complete SHA256-verified release bundle, installs it
under the user account, and starts the TUI. Run `omd` directly afterwards.

Gitee mode persists the `cn` mirror profile. Component installations then use
the USTC Homebrew mirrors and the TUNA Python index. GitHub mode keeps upstream
sources.

## Components

| Category | Components |
| --- | --- |
| Foundation | Linuxbrew, Zsh, uv |
| Development | Git |
| Terminal | ripgrep, fzf, bat, fd, jq, Atuin, Zellij, Yazi, btop, witr |
| Editor | Neovim, LazyVim |
| Configuration | Zsh productivity configuration |

Dependencies are resolved automatically. An external installation can satisfy a
dependency, but oh-my-devpod will neither adopt nor remove it.

## TUI

```text
Tab                 switch install / update / uninstall
Up / Down or j / k  move
Space               select
Enter               review and execute
Esc                 go back or exit
q                   exit
```

Install plans run dependencies first. Uninstall plans run dependants first and
refuse to break installed components.

## Safety

- Only components carrying an oh-my-devpod ownership marker are removed.
- External installations are never adopted or deleted.
- Linuxbrew is protected from the normal uninstall flow.
- Existing shell and editor configuration is preserved before takeover.
- User data, caches, and backups are preserved during configuration removal.
- Release archives must pass SHA256 verification before activation.

## CLI

```bash
omd --list-components
omd --status
omd --plan install lazyvim
omd --plan uninstall lazyvim neovim
omd --execute install ripgrep fzf
omd --version
```

## Repository layout

```text
oh-my-devpod/
├── components.toml
├── install/bootstrap.sh
├── crates/omd/
├── modules/{core,tools,lib}/
├── build/
├── config/
├── vendor/
├── tests/
├── VERSION
└── versions.env
```

`VERSION` is the release-version source of truth.

## Development

```bash
bash tests/run.sh
cargo fmt --all -- --check
cargo test -p omd
cargo run -p omd -- --list-components
cargo run -p omd -- --plan install lazyvim
git diff --check
```

The first release supports Ubuntu 24.04 x86_64.
