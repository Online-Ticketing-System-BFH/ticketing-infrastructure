# 🎫 High-Load Ticketing System - Event & Booking Services

Complete microservices integration with **Hybrid Communication Pattern** (REST + RabbitMQ).

---

## 🚀 Quick Start (1 Minute)

### Prerequisites
Clone all repositories in the **same parent directory**:

```bash
# Clone service repositories
git clone <your-org-url>/highload-event.git
git clone <your-org-url>/highload-booking.git
git clone <your-org-url>/ticketing-infrastructure.git

# Expected structure:
# parent-directory/
# ├── highload-event/
# ├── highload-booking/
# └── ticketing-infrastructure/  # This repo
```

### Deploy

```bash
cd ticketing-infrastructure

# Deploy everything
./start.sh

# Test integration
./test_integration.sh

# Stop services
./stop.sh
```

**Access Services:**
- Event Service: http://localhost:8000/docs
- Booking Service: http://localhost:8001/docs
- RabbitMQ UI: http://localhost:15672 (guest/guest)

---

## 📁 Repository Structure

This is the **infrastructure/orchestration repository**. It references the service repositories:

```
parent-directory/
├── highload-event/              # Event Service Repo (Read-Heavy)
│   ├── app/
│   │   ├── routes/
│   │   │   └── internal.py      # Internal REST API
│   │   ├── services/
│   │   │   └── seat_reservation_service.py
│   │   └── messaging/           # RabbitMQ consumer
│   ├── Dockerfile
│   └── requirements.txt
│
├── highload-booking/            # Booking Service Repo (Write-Heavy)
│   └── booking-service/
│       ├── app/
│       │   └── services/
│       │       ├── event_service_client.py  # HTTP client
│       │       └── reservation_service.py
│       ├── Dockerfile
│       └── requirements.txt
│
└── ticketing-infrastructure/    # This Repo (Orchestration)
    ├── docker-compose.yml       # Orchestrates both services
    ├── start.sh                 # Quick deploy script
    ├── stop.sh                  # Stop script
    ├── test_integration.sh      # Integration tests
    ├── USER_FLOW.md             # Swagger user guide
    └── README.md                # This file
```

**Note:** Service code lives in separate repositories. This repo only contains deployment/orchestration files.

---

## 🏗️ Architecture

### Communication Pattern: **Hybrid (REST + RabbitMQ)**

```
┌─────────────────────────────────────────────────────────────┐
│                    Integration Flow                          │
└─────────────────────────────────────────────────────────────┘

User Books Ticket
    ↓
[Booking Service]
    ↓
    ├─→ 1. Check Availability (REST → Event Service)      ⚡ Sync
    ├─→ 2. Acquire Redis Lock                              🔒 Local
    ├─→ 3. Get Pricing (REST → Event Service)             ⚡ Sync
    ├─→ 4. Reserve Seats (REST → Event Service)           ⚡ Sync
    ├─→ 5. Create Reservation in DB                        💾 Local
    ├─→ 6. Return to User (< 300ms)                        ✅ Done
    ↓
    └─→ 7. Publish Event (RabbitMQ → Event Service)       📡 Async
         ↓
     [Event Service] Consumes Event
         ↓
      Updates Seat Status (sold/available)                 💾 Update
```

### Why Hybrid?

| Aspect | REST (Synchronous) | RabbitMQ (Asynchronous) |
|--------|-------------------|-------------------------|
| **Use Case** | Seat validation, pricing | Status updates, events |
| **Speed** | Fast (< 50ms) | Eventual (< 5s) |
| **Reliability** | Service must be up | Resilient to downtime |
| **User Experience** | Immediate feedback | Background processing |
| **Example** | "Is seat available?" | "Mark seat as sold" |

---

## 📦 Services Overview

### Event Service (Port 8000)
**Responsibility:** Manage events, sessions, seats, availability

**Stack:**
- FastAPI (synchronous)
- PostgreSQL 15
- RabbitMQ consumer
- Redis (optional)

**New Features:**
- ✅ Internal REST API for Booking Service
- ✅ RabbitMQ event consumer
- ✅ Seat reservation management

**Endpoints:**
```
Public API:
  GET  /api/v1/sessions             # List sessions
  GET  /api/v1/sessions/{id}        # Get session
  POST /api/v1/sessions             # Create session
  GET  /api/v1/sessions/{id}/seat-map  # Seat availability

Internal API (for Booking Service):
  POST /api/internal/sessions/{id}/seats/check-availability
  POST /api/internal/sessions/{id}/seats/reserve
  POST /api/internal/sessions/{id}/seats/release
  POST /api/internal/sessions/{id}/seats/confirm
  GET  /api/internal/sessions/{id}/pricing
  GET  /api/internal/health
```

---

### Booking Service (Port 8001)
**Responsibility:** Handle reservations, tickets, payments

**Stack:**
- FastAPI (async)
- PostgreSQL 16 (AsyncPG)
- Redis (seat locking)
- RabbitMQ (event publishing)
- Background worker (expiry)

**Updated Features:**
- ✅ Calls Event Service for seat validation
- ✅ Gets real pricing from Event Service
- ✅ Reserves seats via REST
- ✅ Publishes events to RabbitMQ

**Endpoints:**
```
POST /api/v1/reservations                    # Create reservation
GET  /api/v1/reservations/{id}              # Get reservation
POST /api/v1/reservations/{id}/confirm      # Confirm (triggers RabbitMQ)
DELETE /api/v1/reservations/{id}            # Cancel
GET  /api/v1/tickets/user/{user_id}         # User tickets
```

---

## 🔧 Deployment Options

### Option 1: Automated (Recommended)

```bash
# Start everything
./start.sh

# Check status
docker-compose ps

# View logs
docker-compose logs -f

# Stop
./stop.sh
```

### Option 2: Manual

```bash
# Create network
docker network create ticketing_network

# Start services
docker-compose up -d

# Check health
curl http://localhost:8000/health
curl http://localhost:8001/health

# Stop
docker-compose down
```

### Option 3: Individual Services

```bash
# Terminal 1: Event Service
cd highload-event
docker-compose up

# Terminal 2: Booking Service
cd highload-booking/booking-service
docker-compose up
```

---

## 🧪 Testing

### 1. Automated Health Check

```bash
./test_integration.sh
```

### 2. Manual End-to-End Test

**Step 1: Create test data in Event Service**

Open http://localhost:8000/docs and create:
1. Organizer
2. Event
3. Location
4. Hall
5. Seats (at least 3)
6. Session (auto-creates session_seats)

**Step 2: Create price tier in Booking Service**

Open http://localhost:8001/docs:
```json
POST /api/v1/admin/price-tiers
{
  "name": "Standard",
  "base_multiplier": 1.0,
  "description": "Standard pricing"
}
```

**Step 3: Create reservation**

```bash
USER_ID=$(uuidgen)
SESSION_ID="<your-session-id>"
SEAT_ID="<your-session-seat-id>"
TIER_ID="<your-price-tier-id>"

curl -X POST "http://localhost:8001/api/v1/reservations" \
  -H "Content-Type: application/json" \
  -H "X-User-ID: $USER_ID" \
  -d "{
    \"session_id\": \"$SESSION_ID\",
    \"seats\": [{
      \"session_seat_id\": \"$SEAT_ID\",
      \"price_tier_id\": \"$TIER_ID\",
      \"row_number\": 1,
      \"seat_number\": 1
    }]
  }" | jq
```

**What happens:**
1. ✅ Booking checks availability with Event Service (REST)
2. ✅ Acquires Redis lock
3. ✅ Gets pricing from Event Service (REST)
4. ✅ Reserves seats in Event Service (REST)
5. ✅ Creates reservation
6. ✅ Returns to user

**Step 4: Confirm reservation**

```bash
RESERVATION_ID="<from-previous-response>"

curl -X POST "http://localhost:8001/api/v1/reservations/$RESERVATION_ID/confirm" \
  -H "X-User-ID: $USER_ID" | jq
```

**What happens:**
1. ✅ Booking confirms payment
2. ✅ Publishes `reservation.confirmed` to RabbitMQ
3. ✅ Event Service consumes event
4. ✅ Updates seat to `sold`

**Step 5: Verify**

```bash
# Check Event Service logs
docker logs event-service | grep "reservation.confirmed"

# Check database
docker exec -it event-service-db psql -U postgres -d event_service -c \
  "SELECT status FROM session_seats WHERE session_seat_id = '$SEAT_ID';"
```

Expected: `sold`

---

## 📊 Monitoring

### RabbitMQ UI
http://localhost:15672 (guest/guest)

Check:
- **Exchange**: `ticketing_events` (topic)
- **Queue**: `event_service_queue`
- **Consumers**: Should be 1
- **Messages**: Check publish/delivery rates

### Logs

```bash
# All services
docker-compose logs -f

# Specific service
docker logs -f event-service
docker logs -f booking-service
docker logs -f booking-worker

# Filter
docker logs event-service | grep -i "rabbitmq"
docker logs booking-service | grep -i "published event"
```

### Databases

**Event Service:**
```bash
docker exec -it event-service-db psql -U postgres -d event_service

SELECT ss.session_seat_id, s.row_number, s.seat_number, ss.status
FROM session_seats ss
JOIN seats s ON ss.seat_id = s.seat_id
LIMIT 10;
```

**Booking Service:**
```bash
docker exec -it booking-service-db psql -U booking_user -d booking_db

SELECT id, session_id, status, total_amount
FROM reservations
ORDER BY booking_time DESC
LIMIT 10;
```

---

## 🐛 Troubleshooting

### Services won't start

```bash
# Clean restart
docker-compose down -v
docker network rm ticketing_network
./start.sh
```

### Can't connect between services

```bash
# Check network
docker network inspect ticketing_network

# Test from inside container
docker exec -it booking-service curl http://event-service:8000/health
```

### RabbitMQ not working

```bash
# Check RabbitMQ health
docker exec ticketing-rabbitmq rabbitmq-diagnostics ping

# Check consumers
curl -u guest:guest http://localhost:15672/api/consumers | jq

# Check logs
docker logs ticketing-rabbitmq
docker logs event-service | grep -i rabbitmq
```

### Seats not updating

```bash
# Check Event Service is consuming
docker logs event-service | grep "RabbitMQ consumer started"

# Check queue
curl -u guest:guest http://localhost:15672/api/queues/%2F/event_service_queue | jq

# Manually test
docker exec -it booking-service curl -X POST \
  http://event-service:8000/api/internal/health
```

---

## 📚 Documentation

| File | Description |
|------|-------------|
| `DEPLOYMENT_GUIDE.md` | Complete deployment and testing guide |
| `SERVICE_INTEGRATION.md` | Architecture and integration details |
| `README.md` | This file (overview) |

---

## 🛠️ Tech Stack

### Event Service
- **Framework**: FastAPI 0.119.0
- **Database**: PostgreSQL 15
- **ORM**: SQLAlchemy 2.0.44 (sync)
- **Messaging**: aio-pika 9.3.0
- **Cache**: Redis 5.0.1

### Booking Service
- **Framework**: FastAPI 0.104.1
- **Database**: PostgreSQL 16 (AsyncPG)
- **ORM**: SQLAlchemy 2.0.23 (async)
- **Messaging**: aio-pika 9.3.0
- **Cache**: Redis 7
- **Job Queue**: APScheduler 3.10.4

### Infrastructure
- **Message Broker**: RabbitMQ 3
- **Cache**: Redis 7
- **Orchestration**: Docker Compose
- **Network**: Docker bridge (ticketing_network)

---

## 🎯 Key Features

### ✅ Implemented

- [x] REST API for seat validation
- [x] Real pricing from Event Service
- [x] Seat reservation with timeout
- [x] RabbitMQ event-driven updates
- [x] Distributed locking (Redis)
- [x] Automatic reservation expiry
- [x] Background worker for cleanup
- [x] Docker orchestration
- [x] Health checks
- [x] Comprehensive logging

### 🚧 Future Enhancements

- [ ] Circuit breakers for REST calls
- [ ] Retry logic with exponential backoff
- [ ] Distributed tracing (Jaeger)
- [ ] Prometheus metrics
- [ ] API rate limiting
- [ ] Event replay capability
- [ ] Dead letter queue handling
- [ ] Kubernetes deployment

---

## 📈 Performance

**Booking Flow:**
- Check availability: < 50ms
- Reserve seats: < 100ms
- Total booking time: < 300ms

**Event Processing:**
- RabbitMQ delivery: < 1s
- Status update: < 100ms
- Total event flow: < 5s

**Scalability:**
- Event Service: Horizontal scaling (read replicas)
- Booking Service: Horizontal scaling (stateless)
- RabbitMQ: Clustered for HA
- Redis: Clustered for HA

---

## 🔐 Security Notes

**Current (Development):**
- Default credentials (guest/guest)
- No authentication on internal API
- Mock payment processing

**Production TODO:**
- JWT authentication
- API key for internal endpoints
- Encrypted secrets
- SSL/TLS for all connections
- Rate limiting
- Network policies (Kubernetes)

---

## 📞 Support

**Common Commands:**
```bash
# Start
./start.sh

# Stop
./stop.sh

# Logs
docker-compose logs -f [service-name]

# Restart service
docker-compose restart [service-name]

# Check status
docker-compose ps

# Clean everything
./stop.sh  # Choose option 2
```

**Useful Links:**
- Event Service API: http://localhost:8000/docs
- Booking Service API: http://localhost:8001/docs
- RabbitMQ Management: http://localhost:15672

---

## 🎉 Success!

Both services are now communicating via:
- **REST API** for critical path (booking)
- **RabbitMQ** for async updates (status changes)

Start testing: `./start.sh` → Seed data → Create reservation → Monitor logs!
