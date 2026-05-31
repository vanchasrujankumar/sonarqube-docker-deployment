#!/usr/bin/env bash
set -euo pipefail

SONAR_HOST="${SONAR_HOST:-http://localhost:9000}"
SONAR_USER="${SONAR_USER:-admin}"
SONAR_PASS="${SONAR_PASS:-admin}"

check_deps() {
  for cmd in curl jq; do
    if ! command -v "$cmd" &> /dev/null; then
      echo "Error: $cmd is required but not installed."
      exit 1
    fi
  done
}

check_system_health() {
  echo "=== System Health ==="
  local health
  health=$(curl -sf "${SONAR_HOST}/api/system/health" 2>/dev/null || echo "unreachable")
  echo "Status: $health"
  
  if [ "$health" != "GREEN" ]; then
    echo "WARNING: System health is not GREEN"
    return 1
  fi
}

check_system_status() {
  echo ""
  echo "=== System Status ==="
  local status
  status=$(curl -sf -u "${SONAR_USER}:${SONAR_PASS}" "${SONAR_HOST}/api/system/status" 2>/dev/null || echo "{}")
  echo "$status" | jq . 2>/dev/null || echo "$status"
}

check_plugins() {
  echo ""
  echo "=== Installed Plugins ==="
  curl -sf -u "${SONAR_USER}:${SONAR_PASS}" "${SONAR_HOST}/api/plugins/installed" 2>/dev/null | \
    jq -r '.plugins[] | "\(.key) - \(.name) v\(.version)"' 2>/dev/null || echo "Unable to fetch plugins"
}

check_quality_gates() {
  echo ""
  echo "=== Quality Gates ==="
  curl -sf -u "${SONAR_USER}:${SONAR_PASS}" "${SONAR_HOST}/api/qualitygates/list" 2>/dev/null | \
    jq -r '.qualitygates[] | "\(.name) (default: \(.isDefault))"' 2>/dev/null || echo "Unable to fetch quality gates"
}

main() {
  check_deps
  check_system_health
  check_system_status
  check_plugins
  check_quality_gates
  echo ""
  echo "Health check completed."
}

main "$@"
