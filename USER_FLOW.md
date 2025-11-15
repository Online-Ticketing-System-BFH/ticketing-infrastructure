# Standard User Flow - Ticket Booking System

## 📊 User Flow Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                        USER BOOKING FLOW                        │
└─────────────────────────────────────────────────────────────────┘

┌──────────────┐
│   Browser    │
│   Sessions   │
└──────┬───────┘
       │
       ▼
┌─────────────────────────────────────────────────────────────────┐
│ 1. GET /api/v1/sessions/{session_id}/seat-map                  │
│    Event Service (Port 8000)                                    │
│    → Returns: Available seats with status "available"          │
└──────────────────────────┬──────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│ 2. POST /api/v1/reservations                                    │
│    Booking Service (Port 8001)                                  │
│    Header: X-User-ID: {uuid}                                    │
│    Body: {session_id, seats[]}                                  │
│    → Returns: reservation_id, status: "active"                  │
│                                                                  │
│    Behind the scenes:                                           │
│    ├─→ REST: Check availability (Event Service)                │
│    ├─→ REST: Get pricing (Event Service)                       │
│    ├─→ REST: Reserve seats (Event Service)                     │
│    └─→ Redis: Lock seats                                       │
└──────────────────────────┬──────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│ 3. GET /api/v1/sessions/{session_id}/seat-map                  │
│    Event Service (Port 8000)                                    │
│    → Verify: Seat status changed to "reserved"                 │
└──────────────────────────┬──────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│ 4. POST /api/v1/reservations/{reservation_id}/confirm          │
│    Booking Service (Port 8001)                                  │
│    Header: X-User-ID: {uuid}                                    │
│    Body: {payment_id}                                           │
│    → Returns: status: "confirmed"                               │
│                                                                  │
│    Behind the scenes:                                           │
│    ├─→ Update DB: status = confirmed                           │
│    ├─→ RabbitMQ: Publish "reservation.confirmed" event ──┐     │
│    └─→ Generate ticket                                   │     │
└──────────────────────────────────────────────────────────│─────┘
                                                           │
                           ┌───────────────────────────────┘
                           │ RabbitMQ Message Queue
                           │ Exchange: ticketing_events
                           │ Routing: reservation.confirmed
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│    Event Service Consumer (Background Process)                  │
│    ├─→ Consume "reservation.confirmed" event                   │
│    └─→ Update DB: seat status = "sold"                         │
└──────────────────────────┬──────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│ 5. GET /api/v1/sessions/{session_id}/seat-map                  │
│    Event Service (Port 8000)                                    │
│    → Verify: Seat status changed to "sold" ✓                   │
└──────────────────────────┬──────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│ 6. GET /api/v1/tickets/user/{user_id}                          │
│    Booking Service (Port 8001)                                  │
│    → Returns: Your ticket with QR code                          │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🌐 Swagger UI Access

- **Event Service**: http://localhost:8000/docs
- **Booking Service**: http://localhost:8001/docs

---

## 🎯 Step-by-Step Endpoints

### **STEP 1: View Available Seats**

**Service**: Event Service
**Endpoint**: `GET /api/v1/sessions/{session_id}/seat-map`

**Parameters**:
```
session_id: b623792d-f564-44c4-a6cd-255b83f9a4db
```

**Expected Response**:
```json
{
  "session_id": "b623792d-f564-44c4-a6cd-255b83f9a4db",
  "hall_id": "24c9d755-b21c-42b0-b9d9-42f11e5fe6b5",
  "seats": [
    {
      "session_seat_id": "fd67f9ef-6058-4f48-a6a6-ba4fcf7435cd",
      "seat_id": "09832325-0860-4429-9c9d-5e5325da7af1",
      "row_number": "1",
      "seat_number": "4",
      "price": 100.0,
      "status": "available",
      "reserved_until": null
    },
    {
      "session_seat_id": "42a95132-a946-4569-8bba-010ed85a5ad3",
      "seat_id": "1567af4c-fe5e-4dc4-bf73-bf8bedbf3915",
      "row_number": "1",
      "seat_number": "5",
      "price": 100.0,
      "status": "available",
      "reserved_until": null
    }
  ]
}
```

**Action**: Choose a seat with `"status": "available"` and copy its `session_seat_id`

---

### **STEP 2: Create Reservation**

**Service**: Booking Service
**Endpoint**: `POST /api/v1/reservations`

**Headers**:
```
X-User-ID: 123e4567-e89b-12d3-a456-426614174000
```

**Request Body**:
```json
{
  "session_id": "b623792d-f564-44c4-a6cd-255b83f9a4db",
  "seats": [
    {
      "session_seat_id": "fd67f9ef-6058-4f48-a6a6-ba4fcf7435cd",
      "row_number": "1",
      "seat_number": "4",
      "price_tier_id": "5525e24a-fb4e-46bd-bebb-046efb9ffefe"
    }
  ]
}
```

**Expected Response**:
```json
{
  "id": "a1b2c3d4-5678-90ab-cdef-1234567890ab",
  "user_id": "123e4567-e89b-12d3-a456-426614174000",
  "session_id": "b623792d-f564-44c4-a6cd-255b83f9a4db",
  "booking_time": "2025-11-15T18:00:00Z",
  "expiry_time": "2025-11-15T18:10:00Z",
  "seats_count": 1,
  "total_amount": 100.0,
  "status": "active",
  "items": [
    {
      "id": "...",
      "session_seat_id": "fd67f9ef-6058-4f48-a6a6-ba4fcf7435cd",
      "row_number": "1",
      "seat_number": "4",
      "price": 100.0,
      "discount_amount": 0.0,
      "final_price": 100.0
    }
  ],
  "created_at": "2025-11-15T18:00:00Z",
  "updated_at": "2025-11-15T18:00:00Z",
  "time_remaining_seconds": 600
}
```

**Action**: Copy the `id` field (this is your `reservation_id`)

**Behind the Scenes** (Automatic):
- ✓ Booking Service calls Event Service REST API to check seat availability
- ✓ Booking Service gets pricing from Event Service
- ✓ Booking Service reserves seats in Event Service via REST API
- ✓ Redis locks are acquired to prevent double-booking

---

### **STEP 3: Verify Seat Reserved**

**Service**: Event Service
**Endpoint**: `GET /api/v1/sessions/{session_id}/seat-map`

**Parameters**:
```
session_id: b623792d-f564-44c4-a6cd-255b83f9a4db
```

**What to Check**:
Find your seat (session_seat_id: `fd67f9ef-6058-4f48-a6a6-ba4fcf7435cd`) and verify:

```json
{
  "session_seat_id": "fd67f9ef-6058-4f48-a6a6-ba4fcf7435cd",
  "status": "reserved",  // ← Changed from "available" to "reserved"
  "reserved_until": "2025-11-15T18:10:00Z"
}
```

**✓ Verification**: Status changed to `"reserved"` (you have 10 minutes to complete payment)

---

### **STEP 4: Confirm Reservation (Simulate Payment)**

**Service**: Booking Service
**Endpoint**: `POST /api/v1/reservations/{reservation_id}/confirm`

**Parameters**:
```
reservation_id: (the ID you copied from Step 2)
```

**Headers**:
```
X-User-ID: 123e4567-e89b-12d3-a456-426614174000
```

**Request Body**:
```json
{
  "payment_id": "99999999-0000-0000-0000-000000000001"
}
```

**Expected Response**:
```json
{
  "id": "a1b2c3d4-5678-90ab-cdef-1234567890ab",
  "user_id": "123e4567-e89b-12d3-a456-426614174000",
  "session_id": "b623792d-f564-44c4-a6cd-255b83f9a4db",
  "status": "confirmed",  // ← Status changed from "active" to "confirmed"
  "total_amount": 100.0,
  "seats_count": 1,
  ...
}
```

**Behind the Scenes** (Automatic):
- ✓ Payment is processed (mock payment succeeds)
- ✓ Reservation status updated to "confirmed" in database
- ✓ Ticket is generated with QR code
- ✓ **RabbitMQ event published**: `reservation.confirmed` to exchange `ticketing_events`
- ✓ Event Service consumes the message from RabbitMQ queue
- ✓ Event Service updates seat status to "sold"

---

### **STEP 5: Verify Seat Sold (RabbitMQ Integration Test)**

**⏱️ IMPORTANT**: Wait 2-3 seconds for RabbitMQ message processing

**Service**: Event Service
**Endpoint**: `GET /api/v1/sessions/{session_id}/seat-map`

**Parameters**:
```
session_id: b623792d-f564-44c4-a6cd-255b83f9a4db
```

**What to Check**:
Find your seat and verify:

```json
{
  "session_seat_id": "fd67f9ef-6058-4f48-a6a6-ba4fcf7435cd",
  "status": "sold",  // ← Changed from "reserved" to "sold"
  "reserved_until": "2025-11-15T18:10:00Z"
}
```

**✓ Verification**: Status changed to `"sold"`

**🎉 This proves the complete integration works!**
- REST API: Booking Service → Event Service ✓
- RabbitMQ: Booking Service publishes event ✓
- RabbitMQ: Event Service consumes event ✓
- Database: Seat status updated asynchronously ✓

---

### **STEP 6: View Your Ticket**

**Service**: Booking Service
**Endpoint**: `GET /api/v1/tickets/user/{user_id}`

**Parameters**:
```
user_id: 123e4567-e89b-12d3-a456-426614174000
```

**Expected Response**:
```json
[
  {
    "id": "...",
    "reservation_id": "a1b2c3d4-5678-90ab-cdef-1234567890ab",
    "user_id": "123e4567-e89b-12d3-a456-426614174000",
    "session_id": "b623792d-f564-44c4-a6cd-255b83f9a4db",
    "session_seat_id": "fd67f9ef-6058-4f48-a6a6-ba4fcf7435cd",
    "row_number": "1",
    "seat_number": "4",
    "price": 100.0,
    "status": "active",
    "qr_code": "data:image/png;base64,...",
    "is_used": false,
    "created_at": "2025-11-15T18:05:00Z"
  }
]
```

---

### **OPTIONAL STEP 7: Get QR Code Image**

**Service**: Booking Service
**Endpoint**: `GET /api/v1/tickets/{ticket_id}/qr`

**Parameters**:
```
ticket_id: (from Step 6 response)
```

**Returns**: PNG image of QR code (can be scanned at venue entrance)

---

## 🔑 Quick Reference - Copy-Paste Values

| Field | Value | Usage |
|-------|-------|-------|
| **session_id** | `b623792d-f564-44c4-a6cd-255b83f9a4db` | Steps 1, 2, 3, 5 |
| **user_id** | `123e4567-e89b-12d3-a456-426614174000` | Steps 2, 4, 6 (X-User-ID header) |
| **price_tier_id** | `5525e24a-fb4e-46bd-bebb-046efb9ffefe` | Step 2 (in request body) |
| **Available Seat 1** | `fd67f9ef-6058-4f48-a6a6-ba4fcf7435cd` | Step 2 (Row 1, Seat 4) |
| **Available Seat 2** | `42a95132-a946-4569-8bba-010ed85a5ad3` | Step 2 (Row 1, Seat 5) |

---

## 📋 Ready-to-Use JSON Payloads

### Single Seat Reservation (Step 2)
```json
{
  "session_id": "b623792d-f564-44c4-a6cd-255b83f9a4db",
  "seats": [
    {
      "session_seat_id": "fd67f9ef-6058-4f48-a6a6-ba4fcf7435cd",
      "row_number": "1",
      "seat_number": "4",
      "price_tier_id": "5525e24a-fb4e-46bd-bebb-046efb9ffefe"
    }
  ]
}
```

### Multiple Seats Reservation (Step 2 - Advanced)
```json
{
  "session_id": "b623792d-f564-44c4-a6cd-255b83f9a4db",
  "seats": [
    {
      "session_seat_id": "fd67f9ef-6058-4f48-a6a6-ba4fcf7435cd",
      "row_number": "1",
      "seat_number": "4",
      "price_tier_id": "5525e24a-fb4e-46bd-bebb-046efb9ffefe"
    },
    {
      "session_seat_id": "42a95132-a946-4569-8bba-010ed85a5ad3",
      "row_number": "1",
      "seat_number": "5",
      "price_tier_id": "5525e24a-fb4e-46bd-bebb-046efb9ffefe"
    }
  ]
}
```

### Payment Confirmation (Step 4)
```json
{
  "payment_id": "99999999-0000-0000-0000-000000000001"
}
```

---

## ✅ Verification Checklist

After completing all steps, verify:

- [ ] **Step 1**: Can view seat map with available seats
- [ ] **Step 2**: Reservation created successfully with status `"active"`
- [ ] **Step 3**: Seat status changed to `"reserved"` in Event Service
- [ ] **Step 4**: Reservation confirmed with status `"confirmed"`
- [ ] **Step 5**: Seat status changed to `"sold"` (RabbitMQ worked!)
- [ ] **Step 6**: Ticket visible in user's ticket list

---

## 🔍 What Each Step Tests

| Step | Component Tested | Type |
|------|------------------|------|
| **1** | Event Service - Seat availability | Read Operation |
| **2** | **REST Integration**: Booking → Event (check, price, reserve) | Synchronous Communication |
| **2** | Redis distributed locking | Concurrency Control |
| **3** | Event Service - Seat status management | State Verification |
| **4** | Payment processing & reservation confirmation | Business Logic |
| **4** | **RabbitMQ Publishing**: Event emission | Async Message Production |
| **5** | **RabbitMQ Consuming**: Event processing | Async Message Consumption |
| **5** | Cross-service data consistency | Event-Driven Architecture |
| **6** | Ticket generation with QR code | Ticket Management |

---

## 🐛 Troubleshooting

### "Seat already locked by another user"
**Cause**: Seat is currently reserved
**Solution**: Choose a different seat with `"status": "available"` from Step 1

### "Reservation expired"
**Cause**: More than 10 minutes passed between Steps 2 and 4
**Solution**: Start over from Step 2 (create a new reservation)

### Seat still shows "reserved" in Step 5
**Cause**: RabbitMQ message processing delay
**Solutions**:
1. Wait 2-3 more seconds and refresh
2. Check Event Service logs: `docker logs event-service | tail -20`
3. Check for "Received message" and "confirmed" entries

### "Not Found" or 404 errors
**Cause**: Wrong service or incorrect ID
**Solution**:
- Event Service = port 8000
- Booking Service = port 8001
- Double-check IDs are copied correctly

---

## 🎓 Advanced Testing Scenarios

### Test Concurrent Booking (Race Condition)
1. Open two browser tabs with Swagger
2. Both try to book the same seat simultaneously
3. One should succeed, one should fail with "already locked"

### Test Reservation Expiry
1. Create a reservation (Step 2)
2. Wait 10 minutes without confirming
3. Check seat status - should return to "available"
4. Background worker published `reservation.expired` event

### Test Multiple Seats
1. Use the multi-seat JSON payload in Step 2
2. Verify all seats change to "reserved"
3. Confirm reservation
4. Verify all seats change to "sold"

---

## 📊 System Architecture Verified

```
┌─────────────────┐         REST API          ┌─────────────────┐
│ Booking Service │ ──────────────────────► │  Event Service  │
│   (Port 8001)   │                           │   (Port 8000)   │
│                 │ ◄────────────────────── │                 │
└────────┬────────┘                           └────────▲────────┘
         │                                              │
         │ Publish Event                    Consume Event
         │                                              │
         │    ┌──────────────────────────┐            │
         └───►│      RabbitMQ            │────────────┘
              │  Exchange: ticketing_events           │
              │  Queue: event_service_queue           │
              └──────────────────────────┘
                         │
                         ▼
              ┌──────────────────────────┐
              │        Redis             │
              │  (Distributed Locks)     │
              └──────────────────────────┘
```

**Communication Patterns**:
- ✓ **Synchronous**: REST API calls between services
- ✓ **Asynchronous**: RabbitMQ event-driven updates
- ✓ **Distributed Locking**: Redis for concurrency control

---

## 🚀 Ready to Test!

1. Open http://localhost:8000/docs (Event Service)
2. Open http://localhost:8001/docs (Booking Service)
3. Follow Steps 1-6 above
4. Watch the magic happen! ✨
