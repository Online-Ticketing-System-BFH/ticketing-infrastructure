# Setup Instructions

## ✅ Changes Made

### 1. Updated `docker-compose.yml`
Changed build contexts to reference parent directory:
- `./highload-event` → `../highload-event`
- `./highload-booking/booking-service` → `../highload-booking/booking-service`

### 2. Updated `README.md`
- Added clone instructions
- Updated project structure to show 3 separate repos
- Added prerequisite section

### 3. Added `.gitignore`
Ignores environment files, logs, OS files, etc.

---

## 📂 Required Directory Structure

**IMPORTANT:** All 3 repositories must be in the same parent directory:

```
your-workspace/
├── highload-event/              ← Service repo 1
├── highload-booking/            ← Service repo 2  
└── ticketing-infrastructure/    ← This repo (orchestration)
```

---

## 🚀 Setup Steps

### For New Team Members:

1. **Clone all repositories** (in same parent directory):
   ```bash
   cd ~/your-workspace
   
   git clone <org-url>/highload-event.git
   git clone <org-url>/highload-booking.git
   git clone <org-url>/ticketing-infrastructure.git
   ```

2. **Deploy**:
   ```bash
   cd ticketing-infrastructure
   ./start.sh
   ```

3. **Verify**:
   - Event Service: http://localhost:8000/docs
   - Booking Service: http://localhost:8001/docs
   - RabbitMQ: http://localhost:15672

---

## 📝 Git Setup

### For `ticketing-infrastructure` repo:

```bash
cd ticketing-infrastructure

# Initialize git (if not already)
git init

# Add files
git add docker-compose.yml
git add start.sh stop.sh test_integration.sh
git add USER_FLOW.md README.md
git add .gitignore

# Commit
git commit -m "Initial infrastructure setup"

# Push to your org
git remote add origin <your-org-url>/ticketing-infrastructure.git
git push -u origin main
```

---

## 🔧 Troubleshooting

### "No such file or directory" error when building

**Problem:** docker-compose.yml can't find service directories

**Solution:** Ensure directory structure is correct:
```bash
ls ..
# Should show: highload-event  highload-booking  ticketing-infrastructure
```

### Services won't start

**Problem:** Paths are wrong in docker-compose.yml

**Check:**
```bash
cd ticketing-infrastructure
ls ../highload-event        # Should work
ls ../highload-booking      # Should work
```

---

## ✅ Verification

Run this to verify everything is set up correctly:

```bash
cd ticketing-infrastructure

# Check paths exist
test -d ../highload-event && echo "✓ Event Service found" || echo "✗ Event Service NOT found"
test -d ../highload-booking && echo "✓ Booking Service found" || echo "✗ Booking Service NOT found"

# Try to build (without starting)
docker-compose build --no-cache
```

If all commands succeed, you're ready to deploy!

---

## 📦 What to Commit to Each Repo

### `ticketing-infrastructure` (this repo):
- ✅ `docker-compose.yml`
- ✅ `start.sh`, `stop.sh`, `test_integration.sh`
- ✅ `README.md`, `USER_FLOW.md`
- ✅ `.gitignore`
- ❌ **DO NOT** include service code (app/, Dockerfile from services)

### `highload-event`:
- ✅ All Event Service code (`app/`, `Dockerfile`, `requirements.txt`)
- ❌ **DO NOT** include orchestration files

### `highload-booking`:
- ✅ All Booking Service code (`booking-service/app/`, `Dockerfile`, `requirements.txt`)
- ❌ **DO NOT** include orchestration files

---

## 🎯 Next Steps

1. ✅ Verify directory structure
2. ✅ Test deployment: `./start.sh`
3. ✅ Push to git repositories
4. ✅ Share clone instructions with team
