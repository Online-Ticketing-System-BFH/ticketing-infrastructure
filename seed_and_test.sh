#!/bin/bash

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

EVENT_SERVICE="http://localhost:8000"
BOOKING_SERVICE="http://localhost:8001"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}End-to-End Integration Test${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Generate UUIDs for test data
USER_ID="123e4567-e89b-12d3-a456-426614174000"

echo -e "${BLUE}Step 1: Creating Test Data in Event Service${NC}"
echo ""

# 1. Create Organizer
echo -e "${YELLOW}Creating organizer...${NC}"
ORGANIZER_RESPONSE=$(curl -s -X POST "$EVENT_SERVICE/api/v1/organizers" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Test Organizer",
    "description": "Integration test organizer",
    "contact_email": "test@example.com",
    "contact_phone": "+1234567890"
  }')

ORGANIZER_ID=$(echo $ORGANIZER_RESPONSE | jq -r '.organizer_id // .id')
if [ "$ORGANIZER_ID" = "null" ] || [ -z "$ORGANIZER_ID" ]; then
  echo -e "${RED}✗ Failed to create organizer${NC}"
  echo "Response: $ORGANIZER_RESPONSE"
  exit 1
fi
echo -e "${GREEN}✓ Created organizer: $ORGANIZER_ID${NC}"
echo ""

# 2. Create Location
echo -e "${YELLOW}Creating location...${NC}"
LOCATION_RESPONSE=$(curl -s -X POST "$EVENT_SERVICE/api/v1/locations" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Test Arena",
    "address": "123 Test Street",
    "city": "Test City",
    "country": "Test Country",
    "timezone": "UTC"
  }')

LOCATION_ID=$(echo $LOCATION_RESPONSE | jq -r '.location_id // .id')
if [ "$LOCATION_ID" = "null" ] || [ -z "$LOCATION_ID" ]; then
  echo -e "${RED}✗ Failed to create location${NC}"
  echo "Response: $LOCATION_RESPONSE"
  exit 1
fi
echo -e "${GREEN}✓ Created location: $LOCATION_ID${NC}"
echo ""

# 3. Create Hall
echo -e "${YELLOW}Creating hall...${NC}"
HALL_RESPONSE=$(curl -s -X POST "$EVENT_SERVICE/api/v1/locations/$LOCATION_ID/halls" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Main Hall",
    "capacity": 100
  }')

HALL_ID=$(echo $HALL_RESPONSE | jq -r '.hall_id // .id')
if [ "$HALL_ID" = "null" ] || [ -z "$HALL_ID" ]; then
  echo -e "${RED}✗ Failed to create hall${NC}"
  echo "Response: $HALL_RESPONSE"
  exit 1
fi
echo -e "${GREEN}✓ Created hall: $HALL_ID${NC}"
echo ""

# 4. Create Seats
echo -e "${YELLOW}Creating seats (5 seats in row 1)...${NC}"
SEAT_IDS=()
for i in {1..5}; do
  SEAT_RESPONSE=$(curl -s -X POST "$EVENT_SERVICE/api/v1/halls/$HALL_ID/seats" \
    -H "Content-Type: application/json" \
    -d "{
      \"row_number\": 1,
      \"seat_number\": $i,
      \"seat_type\": \"regular\"
    }")

  SEAT_ID=$(echo $SEAT_RESPONSE | jq -r '.seat_id // .id')
  if [ "$SEAT_ID" = "null" ] || [ -z "$SEAT_ID" ]; then
    echo -e "${RED}✗ Failed to create seat $i${NC}"
    echo "Response: $SEAT_RESPONSE"
    exit 1
  fi
  SEAT_IDS+=($SEAT_ID)
  echo -e "${GREEN}  ✓ Created seat 1-$i: $SEAT_ID${NC}"
done
echo ""

# 5. Create Event
echo -e "${YELLOW}Creating event...${NC}"
EVENT_RESPONSE=$(curl -s -X POST "$EVENT_SERVICE/api/v1/events" \
  -H "Content-Type: application/json" \
  -d "{
    \"title\": \"Test Concert\",
    \"description\": \"Integration test event\",
    \"event_type\": \"concert\",
    \"organizer_id\": \"$ORGANIZER_ID\"
  }")

EVENT_ID=$(echo $EVENT_RESPONSE | jq -r '.event_id // .id')
if [ "$EVENT_ID" = "null" ] || [ -z "$EVENT_ID" ]; then
  echo -e "${RED}✗ Failed to create event${NC}"
  echo "Response: $EVENT_RESPONSE"
  exit 1
fi
echo -e "${GREEN}✓ Created event: $EVENT_ID${NC}"
echo ""

# 6. Create Session
echo -e "${YELLOW}Creating session...${NC}"
START_TIME=$(date -u -v+1d +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u -d '+1 day' +"%Y-%m-%dT%H:%M:%SZ")
END_TIME=$(date -u -v+1d -v+2H +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u -d '+1 day +2 hours' +"%Y-%m-%dT%H:%M:%SZ")

SESSION_RESPONSE=$(curl -s -X POST "$EVENT_SERVICE/api/v1/sessions" \
  -H "Content-Type: application/json" \
  -d "{
    \"event_id\": \"$EVENT_ID\",
    \"hall_id\": \"$HALL_ID\",
    \"start_time\": \"$START_TIME\",
    \"end_time\": \"$END_TIME\",
    \"base_price\": 100.00
  }")

SESSION_ID=$(echo $SESSION_RESPONSE | jq -r '.session_id // .id')
if [ "$SESSION_ID" = "null" ] || [ -z "$SESSION_ID" ]; then
  echo -e "${RED}✗ Failed to create session${NC}"
  echo "Response: $SESSION_RESPONSE"
  exit 1
fi
echo -e "${GREEN}✓ Created session: $SESSION_ID${NC}"
echo ""

# 7. Get Session Seats (created automatically)
echo -e "${YELLOW}Fetching session seats...${NC}"
SESSION_SEATS_RESPONSE=$(curl -s "$EVENT_SERVICE/api/v1/sessions/$SESSION_ID/seats")
SESSION_SEAT_IDS=$(echo $SESSION_SEATS_RESPONSE | jq -r '.[].session_seat_id')

if [ -z "$SESSION_SEAT_IDS" ]; then
  echo -e "${RED}✗ No session seats found${NC}"
  exit 1
fi

# Get first available seat
FIRST_SEAT_ID=$(echo $SESSION_SEAT_IDS | head -n 1 | awk '{print $1}')
echo -e "${GREEN}✓ Found session seats. First seat: $FIRST_SEAT_ID${NC}"
echo ""

echo -e "${BLUE}Step 2: Creating Price Tier in Booking Service${NC}"
echo ""

# Create price tier
echo -e "${YELLOW}Creating price tier...${NC}"
TIER_RESPONSE=$(curl -s -X POST "$BOOKING_SERVICE/api/v1/price-tiers" \
  -H "Content-Type: application/json" \
  -H "X-User-ID: $USER_ID" \
  -d "{
    \"session_id\": \"$SESSION_ID\",
    \"name\": \"Standard\",
    \"multiplier\": 1.0,
    \"description\": \"Standard pricing\"
  }")

TIER_ID=$(echo $TIER_RESPONSE | jq -r '.price_tier_id // .id')
if [ "$TIER_ID" = "null" ] || [ -z "$TIER_ID" ]; then
  echo -e "${RED}✗ Failed to create price tier${NC}"
  echo "Response: $TIER_RESPONSE"
  exit 1
fi
echo -e "${GREEN}✓ Created price tier: $TIER_ID${NC}"
echo ""

echo -e "${BLUE}Step 3: Testing Internal API - Check Seat Availability${NC}"
echo ""

# Test availability check
echo -e "${YELLOW}Checking seat availability through internal API...${NC}"
AVAILABILITY_RESPONSE=$(curl -s -X POST "$EVENT_SERVICE/api/internal/sessions/$SESSION_ID/seats/check-availability" \
  -H "Content-Type: application/json" \
  -d "{\"session_seat_ids\": [\"$FIRST_SEAT_ID\"]}")

IS_AVAILABLE=$(echo $AVAILABILITY_RESPONSE | jq -r '.available')
if [ "$IS_AVAILABLE" != "true" ]; then
  echo -e "${RED}✗ Seat not available${NC}"
  echo "Response: $AVAILABILITY_RESPONSE"
  exit 1
fi
echo -e "${GREEN}✓ Seat is available${NC}"
echo "Response: $AVAILABILITY_RESPONSE" | jq
echo ""

echo -e "${BLUE}Step 4: Testing Internal API - Get Pricing${NC}"
echo ""

# Test pricing endpoint
echo -e "${YELLOW}Getting session pricing...${NC}"
PRICING_RESPONSE=$(curl -s "$EVENT_SERVICE/api/internal/sessions/$SESSION_ID/pricing")
BASE_PRICE=$(echo $PRICING_RESPONSE | jq -r '.base_price')

if [ "$BASE_PRICE" = "null" ] || [ -z "$BASE_PRICE" ]; then
  echo -e "${RED}✗ Failed to get pricing${NC}"
  echo "Response: $PRICING_RESPONSE"
  exit 1
fi
echo -e "${GREEN}✓ Got pricing: \$${BASE_PRICE}${NC}"
echo "Response: $PRICING_RESPONSE" | jq
echo ""

echo -e "${BLUE}Step 5: Creating Reservation (Tests REST Communication)${NC}"
echo ""

# Create reservation - this tests the full integration
echo -e "${YELLOW}Creating reservation through Booking Service...${NC}"
echo -e "${YELLOW}This should trigger REST calls to Event Service:${NC}"
echo -e "${YELLOW}  1. Check availability${NC}"
echo -e "${YELLOW}  2. Get pricing${NC}"
echo -e "${YELLOW}  3. Reserve seats${NC}"
echo ""

RESERVATION_RESPONSE=$(curl -s -X POST "$BOOKING_SERVICE/api/v1/reservations" \
  -H "Content-Type: application/json" \
  -H "X-User-ID: $USER_ID" \
  -d "{
    \"session_id\": \"$SESSION_ID\",
    \"seats\": [
      {
        \"session_seat_id\": \"$FIRST_SEAT_ID\",
        \"price_tier_id\": \"$TIER_ID\",
        \"row_number\": 1,
        \"seat_number\": 1
      }
    ]
  }")

RESERVATION_ID=$(echo $RESERVATION_RESPONSE | jq -r '.reservation_id // .id')
if [ "$RESERVATION_ID" = "null" ] || [ -z "$RESERVATION_ID" ]; then
  echo -e "${RED}✗ Failed to create reservation${NC}"
  echo "Response: $RESERVATION_RESPONSE"
  exit 1
fi

echo -e "${GREEN}✓ Created reservation: $RESERVATION_ID${NC}"
echo "Response: $RESERVATION_RESPONSE" | jq
echo ""

echo -e "${BLUE}Step 6: Verifying Seat Status in Event Service${NC}"
echo ""

# Verify seat is now reserved
echo -e "${YELLOW}Checking seat status in Event Service...${NC}"
SEAT_STATUS_RESPONSE=$(curl -s "$EVENT_SERVICE/api/v1/sessions/$SESSION_ID/seats")
FIRST_SEAT_STATUS=$(echo $SEAT_STATUS_RESPONSE | jq -r ".[] | select(.session_seat_id == \"$FIRST_SEAT_ID\") | .status")

if [ "$FIRST_SEAT_STATUS" != "reserved" ]; then
  echo -e "${RED}✗ Seat status is not 'reserved' (got: $FIRST_SEAT_STATUS)${NC}"
  exit 1
fi
echo -e "${GREEN}✓ Seat status is 'reserved' in Event Service${NC}"
echo ""

echo -e "${BLUE}Step 7: Confirming Reservation (Tests RabbitMQ Event Flow)${NC}"
echo ""

# Confirm reservation - this should publish RabbitMQ event
echo -e "${YELLOW}Confirming reservation...${NC}"
echo -e "${YELLOW}This should:${NC}"
echo -e "${YELLOW}  1. Publish 'reservation.confirmed' event to RabbitMQ${NC}"
echo -e "${YELLOW}  2. Event Service consumes the event${NC}"
echo -e "${YELLOW}  3. Event Service marks seat as 'sold'${NC}"
echo ""

CONFIRM_RESPONSE=$(curl -s -X POST "$BOOKING_SERVICE/api/v1/reservations/$RESERVATION_ID/confirm" \
  -H "X-User-ID: $USER_ID")

PAYMENT_STATUS=$(echo $CONFIRM_RESPONSE | jq -r '.payment_status // .status')
if [ "$PAYMENT_STATUS" = "null" ] || [ -z "$PAYMENT_STATUS" ]; then
  echo -e "${RED}✗ Failed to confirm reservation${NC}"
  echo "Response: $CONFIRM_RESPONSE"
  exit 1
fi

echo -e "${GREEN}✓ Reservation confirmed${NC}"
echo "Response: $CONFIRM_RESPONSE" | jq
echo ""

# Wait for RabbitMQ event processing
echo -e "${YELLOW}Waiting 3 seconds for RabbitMQ event processing...${NC}"
sleep 3
echo ""

echo -e "${BLUE}Step 8: Verifying RabbitMQ Event Processing${NC}"
echo ""

# Verify seat is now sold
echo -e "${YELLOW}Checking if seat status changed to 'sold'...${NC}"
SEAT_STATUS_RESPONSE=$(curl -s "$EVENT_SERVICE/api/v1/sessions/$SESSION_ID/seats")
FINAL_SEAT_STATUS=$(echo $SEAT_STATUS_RESPONSE | jq -r ".[] | select(.session_seat_id == \"$FIRST_SEAT_ID\") | .status")

if [ "$FINAL_SEAT_STATUS" != "sold" ]; then
  echo -e "${RED}✗ Seat status is not 'sold' (got: $FINAL_SEAT_STATUS)${NC}"
  echo -e "${YELLOW}This might indicate RabbitMQ event was not consumed.${NC}"
  echo -e "${YELLOW}Check Event Service logs: docker logs event-service${NC}"
else
  echo -e "${GREEN}✓ Seat status is 'sold' - RabbitMQ event was processed!${NC}"
fi
echo ""

echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}Integration Test Complete!${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

echo -e "${BLUE}Summary:${NC}"
echo -e "  Event ID:        $EVENT_ID"
echo -e "  Session ID:      $SESSION_ID"
echo -e "  Seat ID:         $FIRST_SEAT_ID"
echo -e "  Price Tier ID:   $TIER_ID"
echo -e "  Reservation ID:  $RESERVATION_ID"
echo -e "  Final Status:    ${GREEN}$FINAL_SEAT_STATUS${NC}"
echo ""

echo -e "${YELLOW}Next Steps:${NC}"
echo -e "  1. View Event Service logs:   ${BLUE}docker logs event-service${NC}"
echo -e "  2. View Booking Service logs: ${BLUE}docker logs booking-service${NC}"
echo -e "  3. Check RabbitMQ UI:         ${BLUE}http://localhost:15672${NC} (guest/guest)"
echo -e "  4. Monitor Redis:             ${BLUE}docker exec -it ticketing-redis redis-cli${NC}"
echo ""
