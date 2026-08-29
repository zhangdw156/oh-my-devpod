# Productivity Tool Manager Design

Issue: #105

## Context

oh-my-devpod currently presents a Rust TUI and a set of shell modules, but the
catalog is centered on AI coding CLIs and the TUI does not execute component
actions. The bootstrap installs only the `omd` binary even though runtime
modules and assets remain repository-relative.

The product will be repositioned as an Ubuntu 24.04 productivity-tool manager.
AI coding CLIs and tools installed through `uv tool` are removed completely.
Users enter through a GitHub or Gitee bootstrap, choose tools in a TUI, review
a dependency-aware plan, and install, update, or uninstall managed components.

## Product boundaries

- Ubuntu 24.04 is the supported platform for the first release.
- GitHub and Gitee are distribution mirrors of the same release.
- Components are installed serially in dependency order.
- The first release has a fixed, repository-maintained catalog.
- No plugin marketplace, parallel installer, or general-purpose version solver.
- No AI coding CLI installers or `uv tool`-managed tool installers.
- Uninstall never removes an installation that is not marked as managed by
  oh-my-devpod.
- User configuration, authentication, history, and unrelated package-manager
  state are preserved.

## Runtime bundle

Release archives contain:

```text
oh-my-devpod/
├── bin/omd
├── components.toml
├── modules/
├── build/
├── config/
├── vendor/
├── VERSION
└── versions.env
```

The bootstrap installs the archive into:

```text
~/.local/share/oh-my-devpod/releases/<version>/
```

and updates:

```text
~/.local/bin/omd
```

as a symlink to the selected release. Keeping releases versioned makes upgrades
atomic and leaves an explicit rollback surface.

`omd` resolves its bundle root in this order:

1. `OHMYDEVPOD_BUNDLE_ROOT`
2. the canonicalized executable path (`../` from `bin/omd`)
3. the repository root during development

## Component catalog

`components.toml` is the single source of truth for user-visible components.

Each component defines:

- stable identifier
- display name and description
- category
- module path
- dependency identifiers
- whether normal uninstall is supported

The initial catalog contains:

- foundation: Linuxbrew, Zsh, uv
- development: Git
- terminal: ripgrep, fzf, bat, fd, jq, Atuin, Zellij, Yazi, btop, witr
- editor: Neovim, LazyVim
- configuration: managed Zsh configuration

Dependencies are explicit. Examples:

- Zsh, uv, Git, ripgrep, fzf, bat, fd, and jq require Linuxbrew.
- LazyVim requires Neovim and Git.
- managed Zsh configuration requires Zsh, fzf, and Atuin.

## Planning rules

Install and update plans:

1. Validate requested component identifiers.
2. Compute the transitive dependency closure.
3. Topologically sort dependencies before dependants.
4. Include already-installed dependencies in the plan only when the selected
   action requires them.

Uninstall plans:

1. Inspect installed components.
2. Reject removal when an installed dependant is not also selected.
3. Reject components that do not support normal uninstall.
4. Order dependants before dependencies.
5. Reject unmanaged/external installations.

Catalog loading rejects duplicate identifiers, unknown dependencies, and
dependency cycles.

## Module contract

Every module implements:

```text
status
managed
install [--dry-run]
update [--dry-run]
uninstall [--dry-run]
```

Exit status `0` means the queried state is true or the action succeeded. Exit
status `1` means a queried state is false or an action failed. Contract errors
use exit status `2`.

Ownership markers live under:

```text
${XDG_STATE_HOME:-$HOME/.local/state}/oh-my-devpod/managed/
```

When a command already exists but has no ownership marker, it is reported as an
external installation. Install does not claim ownership, and uninstall refuses
to remove it.

## TUI flow

The TUI has two stages:

1. Select an action and components.
2. Review the resolved plan and execute.

Keys:

- `Tab`: switch install/update/uninstall action
- arrows or `j`/`k`: move
- `Space`: select component
- `Enter`: preview or execute
- `Esc`: return or exit
- `q`: exit

Before executing modules, the TUI restores the normal terminal and leaves the
alternate screen. Module commands inherit stdin/stdout/stderr so `sudo` and
other interactive programs can use the controlling terminal.

## Bootstrap and mirrors

The bootstrap accepts:

```text
OHMYDEVPOD_SOURCE=auto|github|gitee
```

`auto` probes GitHub first and falls back to Gitee. Each source publishes the
same versioned archive and checksum. The bootstrap verifies SHA256 before
extracting and launches the TUI through `/dev/tty` when invoked through a pipe.

The first release supports `x86_64-unknown-linux-gnu`. Unsupported
architectures fail explicitly instead of constructing a release URL that does
not exist.

## Safety invariants

- External installations are never uninstalled.
- Linuxbrew is not removed by the normal uninstall flow.
- A dependency with installed dependants cannot be removed alone.
- Existing configuration is backed up before first takeover.
- Managed configuration is removed only when its ownership marker is present.
- Release archives are checksum-verified before activation.
