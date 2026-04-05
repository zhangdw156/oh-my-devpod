# `openpod` Runtime Asset Migration Design

## Summary

This design removes the remaining OpenCode-specific runtime assets from the shared repository root and moves them fully into `runtime/openpod/`.

After this change:

- the shared layer no longer owns `vendor/opencode/`
- `openpod` becomes the sole owner of OpenCode-specific vendored assets
- `claudepod` and `codexpod` continue to reuse the same upstream `superpowers` skill snapshot, but through `runtime/openpod/` rather than the shared vendor root

The goal is to finish the architectural boundary introduced by the multi-flavor `devpod` refactor.

## Goals

- Remove `vendor/opencode/` from the shared repository root
- Move OpenCode-specific vendored assets under `runtime/openpod/`
- Keep `openpod` fully functional after the move
- Preserve the current `superpowers` skill sync path for `claudepod` and `codexpod`
- Update docs and manifest metadata so the source of truth is unambiguous

## Non-Goals

- Replacing the OpenCode plugin package layout
- Changing the shared `devpod` base
- Redesigning flavor naming or release versioning
- Refactoring Claude or Codex flavor auth/config models

## Current Problem

The repository already moved to a shared-base plus thin-flavor model, but one major boundary leak remains:

- shared root still contains `vendor/opencode/`

That creates two problems:

1. The shared layer still carries `openpod` semantics
2. The `openpod` flavor is not yet self-contained

As long as `vendor/opencode/` stays at the root, the architecture remains only partially migrated.

## Recommended Approach

Use a single-source migration.

Move:

- `vendor/opencode/packages/superpowers/`
- `vendor/opencode/skills/`

to:

- `runtime/openpod/vendor/opencode/packages/superpowers/`
- `runtime/openpod/vendor/opencode/skills/`

Then update all consumers to use the new location.

Do not keep parallel copies in both places.

## Why Single-Source Matters

Keeping both old and new locations would:

- blur ownership
- create drift between copies
- make future updates ambiguous

The only reliable design is one source of truth.

## Target Layout

After migration, the relevant layout should look like:

```text
runtime/
└── openpod/
    ├── bin/
    ├── config/
    ├── install-harness.sh
    ├── skills/
    └── vendor/
        └── opencode/
            ├── packages/
            │   └── superpowers/
            └── skills/
```

The shared root `vendor/` should continue to contain only genuinely shared assets:

- `vendor/releases/`
- `vendor/zsh/`
- `vendor/nvim/`

## Runtime Impact

### `openpod`

`Dockerfile.openpod` and `runtime/openpod/install-harness.sh` must read all OpenCode-specific assets only from `runtime/openpod/`.

That includes:

- default OpenCode config
- vendored plugin entrypoint
- vendored global skills

### `claudepod` and `codexpod`

These flavors currently reuse the OpenCode vendored `superpowers` skills snapshot as the source for:

- `runtime/claudepod/skills/superpowers/`
- `runtime/codexpod/skills/superpowers/`

That reuse should continue, but the source path changes from:

- `vendor/opencode/packages/superpowers/skills`

to:

- `runtime/openpod/vendor/opencode/packages/superpowers/skills`

## Update Workflow Impact

`build/update-vendor-assets.sh` must change accordingly:

- refresh OpenCode vendored assets into `runtime/openpod/vendor/opencode/...`
- then sync the `superpowers/skills` subtree into the Claude and Codex flavor skill directories

This keeps all flavors on the same upstream `superpowers` snapshot while preserving ownership boundaries.

## Docs And Metadata Impact

The following must be updated:

- `docs/vendor-assets.md`
- `DEVELOPMENT.md`
- `AGENTS.md`
- `vendor/manifest.lock.json`

They should no longer describe `vendor/opencode/` as a shared root asset.

Instead they should describe:

- `runtime/openpod/vendor/opencode/...` as the OpenCode flavor asset root
- `runtime/claudepod/skills/...` and `runtime/codexpod/skills/...` as flavor-owned synchronized skill trees

## Risks

### Plugin Relative-Path Breakage

The upstream OpenCode plugin expects its package-root layout and resolves paths relative to its entrypoint.

The migration must preserve that package-root layout exactly under the new path.

### Skill Sync Drift

If the update script stops syncing `superpowers` skills correctly after the move, Claude and Codex flavors will drift from OpenCode's vendored snapshot.

### Partial Documentation Update

If docs still mention root-level `vendor/opencode/`, future maintenance will target the wrong location.

## Verification Requirements

This migration is complete only if all of the following are true:

- root `vendor/` no longer contains `vendor/opencode/`
- `openpod` still builds and runs
- `claudepod` and `codexpod` still get synchronized `superpowers` skills
- `build/update-vendor-assets.sh` still succeeds
- docs and manifest metadata point to the new source of truth

Recommended verification commands:

- `bash build/update-vendor-assets.sh`
- `bash tests/run.sh`
- `docker compose build devpod openpod claudepod codexpod`
- `docker compose run --rm openpod -lc 'opencode --version'`
- `docker compose run --rm claudepod -lc 'claude --version && claude auth status'`
- `docker compose run --rm codexpod -lc 'codex --help | sed -n "1,20p"'`
- `bash install/bootstrap.sh --flavor openpod --user`
- `bash install/bootstrap.sh --flavor claudepod --user`
- `bash install/bootstrap.sh --flavor codexpod --user`

## Implementation Boundary

The implementation plan for this design should cover:

- moving OpenCode vendored assets into `runtime/openpod/`
- updating `openpod` runtime consumers
- updating flavor skill sync in `build/update-vendor-assets.sh`
- updating docs and manifest metadata
- running the full verification set

It should not change the shared `devpod` base or redesign flavor behavior beyond this asset ownership move.
