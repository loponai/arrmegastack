#!/usr/bin/env bash
# ==========================================
# MegaStack - Health Check Script
# Checks container health and service availability
# ==========================================

set -euo pipefail

MS_ROOT="${MS_ROOT:-/opt/megastack}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

check_container() {
    local name="$1"
    local port="${2:-}"

    local status
    status=$(docker inspect --format='{{.State.Status}}' "${name}" 2>/dev/null || echo "not found")

    case "${status}" in
        running)
            local health
            health=$(docker inspect --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}no healthcheck{{end}}' "${name}" 2>/dev/null || echo "unknown")

            if [[ "${health}" == "unhealthy" ]]; then
                echo -e "  ${YELLOW}!${NC} ${name}: running (unhealthy)"
                return 1
            else
                echo -e "  ${GREEN}✓${NC} ${name}: running"
            fi

            # Check port if specified
            if [[ -n "${port}" ]]; then
                if curl -sf -o /dev/null --connect-timeout 3 "http://localhost:${port}" 2>/dev/null; then
                    echo -e "      Port ${port}: ${GREEN}responding${NC}"
                else
                    echo -e "      Port ${port}: ${YELLOW}not responding${NC}"
                fi
            fi
            return 0
            ;;
        *)
            echo -e "  ${RED}✗${NC} ${name}: ${status}"
            return 1
            ;;
    esac
}

echo "MegaStack Health Check"
echo "======================"
echo ""

errors=0

# Core
echo "Core:"
check_container "ms-npm" "81" || ((errors++))
check_container "ms-portainer" "9000" || ((errors++))
check_container "ms-homepage" "3000" || ((errors++))
echo ""

# Dashboard
echo "Dashboard:"
check_container "ms-dashboard" "8443" || ((errors++))
echo ""

# Media
echo "Media:"
check_container "ms-gluetun" || ((errors++))
check_container "ms-qbittorrent" || ((errors++))
check_container "ms-prowlarr" || ((errors++))
check_container "ms-sonarr" || ((errors++))
check_container "ms-radarr" || ((errors++))
check_container "ms-jellyfin" "8096" || ((errors++))
echo ""

# Summary
echo "======================"
if [[ ${errors} -eq 0 ]]; then
    echo -e "${GREEN}All services healthy.${NC}"
else
    echo -e "${YELLOW}${errors} issue(s) detected.${NC}"
fi

exit ${errors}
