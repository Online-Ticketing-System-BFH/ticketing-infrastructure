#!/bin/bash

# Integration Test Script for Event ↔ Booking Service Communication
# Tests the hybrid REST + RabbitMQ communication pattern

set -e  # Exit on any error

BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

EVENT_SERVICE_URL="http://localhost:8000"
BOOKING_SERVICE_URL="http://localhost:8001"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Event ↔ Booking Service Integration Test${NC}"
echo -e "${BLUE}========================================${NC}\n"

# Function to check service health
check_health() {
    local service_name=$1
    local url=$2
    echo -e "${YELLOW}[TEST]${NC} Checking $service_name health..."

    response=$(curl -s -w "\n%{http_code}" "$url")
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')

    if [ "$http_code" -eq 200 ]; then
        echo -e "${GREEN}✓${NC} $service_name is healthy"
        echo "  Response: $body"
        return 0
    else
        echo -e "${RED}✗${NC} $service_name health check failed (HTTP $http_code)"
        return 1
    fi
}

# Function to test Event Service internal API
test_event_internal_api() {
    echo -e "\n${YELLOW}[TEST]${NC} Testing Event Service Internal API..."

    # Test health endpoint
    response=$(curl -s -w "\n%{http_code}" "$EVENT_SERVICE_URL/api/internal/health")
    http_code=$(echo "$response" | tail -n1)

    if [ "$http_code" -eq 200 ]; then
        echo -e "${GREEN}✓${NC} Internal API health endpoint works"
    else
        echo -e "${RED}✗${NC} Internal API health check failed (HTTP $http_code)"
        return 1
    fi
}

# Function to test seat availability check
test_seat_availability() {
    echo -e "\n${YELLOW}[TEST]${NC} Testing Seat Availability Check..."
    echo "Note: This requires a valid session_id and session_seat_id from Event Service database"
    echo "Skipping for now - manual testing required after data seeding"
    echo -e "${YELLOW}→${NC} See manual test instructions below"
}

# Function to test Booking→Event communication
test_booking_event_communication() {
    echo -e "\n${YELLOW}[TEST]${NC} Testing Booking → Event Service Communication..."
    echo "Note: This requires creating a reservation through Booking Service"
    echo "The Booking Service should call Event Service internal API"
    echo -e "${YELLOW}→${NC} See manual test instructions below"
}

# Function to test RabbitMQ integration
test_rabbitmq_integration() {
    echo -e "\n${YELLOW}[TEST]${NC} Testing RabbitMQ Event Integration..."
    echo "Note: This requires RabbitMQ management UI access"

    echo -e "${YELLOW}→${NC} Check RabbitMQ Management UI: http://localhost:15672"
    echo "  Username: guest, Password: guest"
    echo "  Look for:"
    echo "    - Exchange: 'ticketing_events' (type: topic)"
    echo "    - Queue: 'event_service_queue'"
    echo "    - Bindings: reservation.confirmed, reservation.expired, ticket.refunded"
}

# Main test execution
main() {
    echo -e "${BLUE}Step 1: Service Health Checks${NC}\n"

    check_health "Event Service" "$EVENT_SERVICE_URL/health" || exit 1
    check_health "Booking Service" "$BOOKING_SERVICE_URL/health" || exit 1

    test_event_internal_api || exit 1

    test_seat_availability
    test_booking_event_communication
    test_rabbitmq_integration

    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${GREEN}Basic Integration Tests Passed!${NC}"
    echo -e "${BLUE}========================================${NC}\n"

    echo -e "${YELLOW}Manual Testing Instructions:${NC}\n"

    echo -e "${BLUE}1. Seed Event Service Data:${NC}"
    echo "   cd highload-event"
    echo "   # Create organizer, event, location, hall, seats, session"
    echo ""

    echo -e "${BLUE}2. Test Seat Availability:${NC}"
    echo "   SESSION_ID=<your-session-id>"
    echo "   SEAT_ID=<your-session-seat-id>"
    echo ""
    echo "   curl -X POST \"$EVENT_SERVICE_URL/api/internal/sessions/\$SESSION_ID/seats/check-availability\" \\"
    echo "     -H \"Content-Type: application/json\" \\"
    echo "     -d '{\"session_seat_ids\": [\"'\$SEAT_ID'\"]}' | jq"
    echo ""

    echo -e "${BLUE}3. Test Booking Flow (End-to-End):${NC}"
    echo "   # Create a reservation through Booking Service"
    echo "   curl -X POST \"$BOOKING_SERVICE_URL/api/v1/reservations\" \\"
    echo "     -H \"Content-Type: application/json\" \\"
    echo "     -H \"X-User-ID: <user-uuid>\" \\"
    echo "     -d '{"
    echo "       \"session_id\": \"<session-uuid>\","
    echo "       \"seats\": ["
    echo "         {"
    echo "           \"session_seat_id\": \"<seat-uuid>\","
    echo "           \"price_tier_id\": \"<tier-uuid>\","
    echo "           \"row_number\": 1,"
    echo "           \"seat_number\": 1"
    echo "         }"
    echo "       ]"
    echo "     }' | jq"
    echo ""
    echo "   # This should:"
    echo "   # 1. Call Event Service to check availability"
    echo "   # 2. Acquire Redis lock"
    echo "   # 3. Get pricing from Event Service"
    echo "   # 4. Reserve seats in Event Service (REST)"
    echo "   # 5. Create reservation in Booking DB"
    echo ""

    echo -e "${BLUE}4. Verify RabbitMQ Event Flow:${NC}"
    echo "   # Confirm the reservation (triggers RabbitMQ event)"
    echo "   RESERVATION_ID=<reservation-id>"
    echo "   curl -X POST \"$BOOKING_SERVICE_URL/api/v1/reservations/\$RESERVATION_ID/confirm\" \\"
    echo "     -H \"X-User-ID: <user-uuid>\" | jq"
    echo ""
    echo "   # Then check Event Service database:"
    echo "   # SELECT status FROM session_seats WHERE session_seat_id = '<seat-uuid>';"
    echo "   # Status should be 'sold'"
    echo ""

    echo -e "${BLUE}5. Test Expiry Flow:${NC}"
    echo "   # Wait 10 minutes for reservation to expire"
    echo "   # Booking worker should publish reservation.expired event"
    echo "   # Event Service should consume it and release seats"
    echo "   # Status should change from 'reserved' back to 'available'"
    echo ""

    echo -e "${BLUE}6. Monitor Logs:${NC}"
    echo "   # Event Service logs:"
    echo "   docker logs -f event-service"
    echo ""
    echo "   # Booking Service logs:"
    echo "   docker logs -f booking-service"
    echo ""
    echo "   # Look for:"
    echo "   #  - 'RabbitMQ consumer started successfully'"
    echo "   #  - 'Received message' (in Event Service)"
    echo "   #  - 'Published event' (in Booking Service)"
    echo ""

    echo -e "${GREEN}Integration is ready! Follow the manual steps above to test end-to-end.${NC}\n"
}

# Run tests
main
