#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"
# shellcheck source=source-config.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/source-config.sh"

action="${1:-}"
case "${action}" in
  install|update) ;;
  *) omd_module_unknown_action "${1:-}" ;;
esac

case "${OHMYDEVPOD_MIRROR_PROFILE:-upstream}" in
  cn) source_name="gitee" ;;
  upstream) source_name="github" ;;
  *)
    omd_module_info notice "unknown mirror profile; native source configuration was not changed"
    source_name=""
    ;;
esac
if [[ -n "${source_name}" ]] &&
  ! omd_source_config_apply_transactional "${source_name}"; then
  omd_module_info error "failed to apply native source configuration"
  exit 1
fi
