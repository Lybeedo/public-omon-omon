#!/bin/bash
# VicChelenge System - Quick Verification Script
# Runs after deployment to verify all services are healthy
# Usage: ./QUICKSTART.sh

set -e

echo "=========================================="
echo "   VicChelenge System Health Check"
echo "=========================================="
echo ""

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Counter for results
PASSED=0
FAILED=0

check_service() {
    local name=$1
    local url=$2
    local timeout=5
    
    echo -n "  Checking $name... "
    
    # Use timeout and capture HTTP status
    status=$(curl -sf "$url" --connect-timeout $timeout -w "%{http_code}" -o /dev/null 2>&1 || echo "000")
    
    if [ "$status" = "200" ] || [ "$status" = "204" ]; then
        echo -e "${GREEN}✓ OK${NC} (HTTP $status)"
        ((PASSED++))
        return 0
    else
        echo -e "${RED}✗ FAILED${NC} (HTTP $status)"
        ((FAILED++))
        return 1
    fi
}

echo "Service Health Checks:"
echo "----------------------"
check_service "nexus-api" "http://localhost:8000/health"
check_service "nexus-regime" "http://localhost:8001/health"
check_service "nexus-llm" "http://localhost:8002/health"
check_service "nexus-optimizer" "http://localhost:8003/health"

echo ""
echo "Docker Compose Validation:"
echo "--------------------------"

# Check if docker-compose.yml exists
if [ -f "deploy/docker-compose.yml" ]; then
    # Validate compose file syntax
    if docker compose -f deploy/docker-compose.yml config > /dev/null 2>&1; then
        echo -e "  ${GREEN}✓${NC} docker-compose.yml is valid"
        ((PASSED++))
    else
        echo -e "  ${RED}✗${NC} docker-compose.yml has errors"
        ((FAILED++))
    fi
    
    # Check running containers
    echo ""
    echo "Running Containers:"
    echo "-------------------"
    docker compose -f deploy/docker-compose.yml ps --format json 2>/dev/null | jq -r '.Name + " - " + .State' 2>/dev/null || \
    docker compose -f deploy/docker-compose.yml ps 2>/dev/null || \
    echo -e "  ${YELLOW}!${NC} Could not retrieve container status"
else
    echo -e "  ${YELLOW}!${NC} deploy/docker-compose.yml not found"
fi

echo ""
echo "=========================================="
echo "   Summary"
echo "=========================================="
echo -e "  Passed: ${GREEN}$PASSED${NC}"
echo -e "  Failed: ${RED}$FAILED${NC}"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}All checks passed! System is healthy.${NC}"
    exit 0
else
    echo -e "${RED}Some checks failed. Please review the errors above.${NC}"
    exit 1
fi