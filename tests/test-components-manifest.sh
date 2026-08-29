#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
manifest="${repo_root}/components.toml"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

[[ -f "${manifest}" ]] || fail "missing component catalog: components.toml"

python3 - "${manifest}" <<'PY'
import pathlib
import sys
import tomllib

manifest = pathlib.Path(sys.argv[1])
with manifest.open("rb") as handle:
    data = tomllib.load(handle)

components = data.get("component")
if not isinstance(components, list) or not components:
    raise SystemExit("FAIL: components.toml must define a non-empty [[component]] array")

required_fields = {
    "id",
    "name",
    "description",
    "category",
    "module",
    "requires",
    "install_requires",
    "uninstall",
}
ids = []
by_id = {}
allowed_categories = {"foundation", "development", "terminal", "editor", "configuration"}
for component in components:
    missing = sorted(required_fields - component.keys())
    if missing:
        raise SystemExit(
            f"FAIL: component {component.get('id', '<unknown>')} is missing fields: {', '.join(missing)}"
        )
    component_id = component["id"]
    if component_id in by_id:
        raise SystemExit(f"FAIL: duplicate component id: {component_id}")
    if not isinstance(component["requires"], list):
        raise SystemExit(f"FAIL: {component_id}.requires must be an array")
    if not isinstance(component["install_requires"], list):
        raise SystemExit(f"FAIL: {component_id}.install_requires must be an array")
    if not isinstance(component["uninstall"], bool):
        raise SystemExit(f"FAIL: {component_id}.uninstall must be a boolean")
    if component["category"] not in allowed_categories:
        raise SystemExit(
            f"FAIL: {component_id} has unsupported category: {component['category']}"
        )
    declared_dependencies = component["requires"] + component["install_requires"]
    if component_id in declared_dependencies:
        raise SystemExit(f"FAIL: {component_id} depends on itself")
    if len(declared_dependencies) != len(set(declared_dependencies)):
        raise SystemExit(f"FAIL: {component_id} declares duplicate dependencies")
    ids.append(component_id)
    by_id[component_id] = component

forbidden = ("claude", "codex", "opencode", "copilot", "gemini")
for component in components:
    searchable = " ".join(
        str(component.get(field, "")).lower()
        for field in ("id", "name", "description", "module")
    )
    for token in forbidden:
        if token in searchable:
            raise SystemExit(
                f"FAIL: AI coding CLI token '{token}' remains in component {component['id']}"
            )

minimum_ids = {
    "git",
    "zsh",
    "uv",
    "micromamba",
    "fzf",
    "atuin",
    "neovim",
    "lazyvim",
}
missing_ids = sorted(minimum_ids - set(ids))
if missing_ids:
    raise SystemExit(
        "FAIL: productivity catalog is missing components: " + ", ".join(missing_ids)
    )

if len(components) < 10:
    raise SystemExit("FAIL: initial productivity catalog should contain at least 10 components")

def require_dependencies(component_id, expected):
    actual = set(by_id[component_id]["requires"])
    missing = sorted(set(expected) - actual)
    if missing:
        raise SystemExit(
            f"FAIL: {component_id} is missing dependencies: {', '.join(missing)}"
        )

def require_component_shape(component_id, expected):
    actual = by_id[component_id]
    mismatches = [
        f"{field}={actual.get(field)!r}, expected {value!r}"
        for field, value in expected.items()
        if actual.get(field) != value
    ]
    if mismatches:
        raise SystemExit(
            f"FAIL: {component_id} has invalid manifest shape: " + "; ".join(mismatches)
        )

require_component_shape(
    "micromamba",
    {
        "category": "foundation",
        "module": "modules/core/micromamba.sh",
        "requires": [],
        "install_requires": ["linuxbrew"],
        "uninstall": True,
    },
)

require_dependencies("lazyvim", {"neovim", "git"})

zsh_config = by_id.get("zsh-config") or by_id.get("managed-zsh-config")
if zsh_config is None:
    raise SystemExit("FAIL: catalog must include zsh-config or managed-zsh-config")
missing = {"zsh", "fzf", "atuin"} - set(zsh_config["requires"])
if missing:
    raise SystemExit(
        f"FAIL: {zsh_config['id']} is missing dependencies: {', '.join(sorted(missing))}"
    )

known = set(ids)
for component in components:
    unknown = sorted(
        (set(component["requires"]) | set(component["install_requires"])) - known
    )
    if unknown:
        raise SystemExit(
            f"FAIL: {component['id']} has unknown dependencies: {', '.join(unknown)}"
        )
PY
