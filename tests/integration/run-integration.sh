#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
test_dir="${repo_root}/tests/integration"

passed=0
failed=0
results=()

run_test() {
  local name="$1"
  local script="$2"
  echo ""
  echo "========================================"
  echo "  ${name}"
  echo "========================================"
  if bash "${script}"; then
    results+=("PASS  ${name}")
    ((passed++))
  else
    results+=("FAIL  ${name}")
    ((failed++))
  fi
}

run_test "Image Build & Tool Verification" "${test_dir}/test-image-build.sh"
run_test "Docker Compose Workflows"        "${test_dir}/test-compose.sh"
run_test "Bootstrap (Homebrew, no sudo)"   "${test_dir}/test-bootstrap.sh"

echo ""
echo "========================================"
echo "  Integration Test Summary"
echo "========================================"
for r in "${results[@]}"; do
  echo "  ${r}"
done
echo ""
echo "  Total: $((passed + failed))  Passed: ${passed}  Failed: ${failed}"
echo "========================================"

[[ "${failed}" -eq 0 ]]
