#!/bin/bash

# Stop Script for Event + Booking Services

set -e

# Colors
BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}"
echo "╔════════════════════════════════════════════════╗"
echo "║   Stopping Event + Booking Services           ║"
echo "╚════════════════════════════════════════════════╝"
echo -e "${NC}\n"

# Ask for confirmation
echo -e "${YELLOW}What would you like to do?${NC}"
echo "  1) Stop services (keep data)"
echo "  2) Stop services and remove volumes (delete all data)"
echo "  3) Cancel"
echo ""
read -p "Enter choice [1-3]: " choice

case $choice in
    1)
        echo -e "\n${YELLOW}Stopping services...${NC}"
        docker-compose down
        echo -e "${GREEN}✓ Services stopped${NC}"
        echo -e "${BLUE}💡 Data is preserved. Run './start.sh' to restart.${NC}"
        ;;
    2)
        echo -e "\n${RED}⚠️  This will delete all data (databases, queues, etc.)${NC}"
        read -p "Are you sure? (yes/no): " confirm
        if [ "$confirm" = "yes" ]; then
            echo -e "\n${YELLOW}Stopping services and removing volumes...${NC}"
            docker-compose down -v
            echo -e "${YELLOW}Removing network...${NC}"
            docker network rm ticketing_network 2>/dev/null || true
            echo -e "${GREEN}✓ Services stopped and data removed${NC}"
            echo -e "${BLUE}💡 Run './start.sh' to deploy fresh.${NC}"
        else
            echo -e "${YELLOW}Cancelled.${NC}"
        fi
        ;;
    3)
        echo -e "${YELLOW}Cancelled.${NC}"
        exit 0
        ;;
    *)
        echo -e "${RED}Invalid choice. Cancelled.${NC}"
        exit 1
        ;;
esac

echo ""
