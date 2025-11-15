#!/bin/bash

# Quick Start Script for Event + Booking Services
# Automates deployment and verification

set -e

# Colors
BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}"
echo "╔════════════════════════════════════════════════╗"
echo "║   Event + Booking Services Quick Start        ║"
echo "╚════════════════════════════════════════════════╝"
echo -e "${NC}\n"

# Check prerequisites
echo -e "${YELLOW}[1/6]${NC} Checking prerequisites..."

if ! command -v docker &> /dev/null; then
    echo -e "${RED}✗ Docker not found. Please install Docker first.${NC}"
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    echo -e "${RED}✗ Docker Compose not found. Please install Docker Compose first.${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Docker and Docker Compose found${NC}\n"

# Check if ports are available
echo -e "${YELLOW}[2/6]${NC} Checking ports..."

check_port() {
    port=$1
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
        echo -e "${YELLOW}⚠ Port $port is in use${NC}"
        return 1
    else
        echo -e "${GREEN}✓ Port $port is available${NC}"
        return 0
    fi
}

PORTS_OK=true
check_port 8000 || PORTS_OK=false
check_port 8001 || PORTS_OK=false
check_port 5672 || PORTS_OK=false
check_port 6379 || PORTS_OK=false
check_port 15672 || PORTS_OK=false

if [ "$PORTS_OK" = false ]; then
    echo -e "${YELLOW}Some ports are in use. Do you want to stop existing containers? (y/n)${NC}"
    read -r response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        echo "Stopping existing containers..."
        docker-compose down 2>/dev/null || true
    fi
fi

echo ""

# Create network
echo -e "${YELLOW}[3/6]${NC} Creating Docker network..."
if docker network inspect ticketing_network >/dev/null 2>&1; then
    echo -e "${GREEN}✓ Network 'ticketing_network' already exists${NC}"
else
    docker network create ticketing_network
    echo -e "${GREEN}✓ Network 'ticketing_network' created${NC}"
fi

echo ""

# Start services
echo -e "${YELLOW}[4/6]${NC} Starting services..."
echo -e "${BLUE}This may take a few minutes on first run (downloading images)...${NC}"

docker-compose up -d

echo -e "${GREEN}✓ Services started${NC}\n"

# Wait for services
echo -e "${YELLOW}[5/6]${NC} Waiting for services to be ready..."
echo -e "${BLUE}Please wait 30 seconds...${NC}"

for i in {30..1}; do
    echo -ne "${BLUE}$i seconds remaining...\r${NC}"
    sleep 1
done
echo ""

# Verify health
echo -e "${YELLOW}[6/6]${NC} Verifying services..."

verify_service() {
    service_name=$1
    url=$2

    if curl -s -f "$url" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ $service_name is healthy${NC}"
        return 0
    else
        echo -e "${RED}✗ $service_name is not responding${NC}"
        return 1
    fi
}

ALL_HEALTHY=true
verify_service "Event Service" "http://localhost:8000/health" || ALL_HEALTHY=false
verify_service "Booking Service" "http://localhost:8001/health" || ALL_HEALTHY=false
verify_service "Internal API" "http://localhost:8000/api/internal/health" || ALL_HEALTHY=false
verify_service "RabbitMQ" "http://localhost:15672" || ALL_HEALTHY=false

echo ""

# Show status
echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
if [ "$ALL_HEALTHY" = true ]; then
    echo -e "${GREEN}║   ✅ All services are running successfully!   ║${NC}"
else
    echo -e "${YELLOW}║   ⚠️  Some services may need more time        ║${NC}"
fi
echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}\n"

# Show URLs
echo -e "${BLUE}📊 Service URLs:${NC}"
echo -e "   Event Service:      ${GREEN}http://localhost:8000${NC}"
echo -e "   Event Service Docs: ${GREEN}http://localhost:8000/docs${NC}"
echo -e "   Booking Service:    ${GREEN}http://localhost:8001${NC}"
echo -e "   Booking Service Docs: ${GREEN}http://localhost:8001/docs${NC}"
echo -e "   RabbitMQ UI:        ${GREEN}http://localhost:15672${NC} (guest/guest)"
echo ""

# Show next steps
echo -e "${BLUE}📝 Next Steps:${NC}"
echo -e "   1. Seed test data: ${YELLOW}Open http://localhost:8000/docs${NC}"
echo -e "   2. Follow testing guide: ${YELLOW}cat DEPLOYMENT_GUIDE.md${NC}"
echo -e "   3. View logs: ${YELLOW}docker-compose logs -f${NC}"
echo -e "   4. Stop services: ${YELLOW}docker-compose down${NC}"
echo ""

# Show container status
echo -e "${BLUE}🐳 Container Status:${NC}"
docker-compose ps

echo ""
echo -e "${GREEN}✅ Deployment complete!${NC}"
echo -e "${YELLOW}💡 Tip: Run './test_integration.sh' to test the integration${NC}\n"
