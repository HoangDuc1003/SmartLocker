# SmartLocker: System Architecture & Business Flows

This document details the operational data paths, lifecycle state machines, and business rules implemented in SmartLocker (v3).
Detailed device API contracts are defined in `spec/smart-locker-v2.md` Section 4; v3 enhancements (size-based pricing, cancellation refunds, automatic check-in on hold expiry, overdue locking, debt handling, and staff escalation) are detailed in `spec/smart-locker-v3.md`.
All core numerical parameters (15-min hold, 5-min cancellation window, 50% late cancellation refund, 10,000 VND safety buffer, 150% late fee rate, 48-hour escalation threshold) are centralized in database table `AppConfig`.

---

## Part 1: Dashboard and Background Daemons

### 1.1 Data Flow

```mermaid
flowchart TD
    DB[(SQL Server)] -->|aggregated query every 2 seconds| LM["LockerMonitor (daemon thread)"]
    LM -->|atomically replaces snapshot| CACHE["AtomicReference&lt;Snapshot&gt;"]
    API["DashboardApi /api/dashboard"] -->|reads memory snapshot, 0 DB queries| CACHE
    Stats["DashboardStatsApi /api/dashboard/stats"] -->|aggregated metrics, 60-second cache| DB[(SQL Server)]
    Charts["js/dash-charts.js"] -->|polls every 60 seconds| Stats
    Page["dashboard.jsp + js/dashboard.js"] -->|polls every 5 s, cancels after 8 s via AbortController| API
    LM -->|executes every 15 seconds| PROC["Procedures: Device_MarkOffline(90), Deposit_ExpireNoShow,
    Deposit_ExpireOverdue (locks + assesses late fee), Deposit_Escalate (48 h), RemoteCommand_Expire"]
    LM -->|dedicated thread| MAIL["DueReminder: Deposit_DueSoon, dispatches emails, Deposit_MarkReminded"]
```

### 1.2 Core Components
1. **`LockerMonitor`** (`ServletContextListener`, background thread):
   - Every 2 seconds builds an in-memory `Snapshot` (KPIs, slot status breakdown, active alerts, device connectivity, recent access events) and runs `AuditVerifier` across the cryptographic hash chain.
   - Every 15 seconds invokes lifecycle expiry stored procedures. Devices silent for >90 seconds transition to `OFFLINE`.
   - Simulated units (`"demo":true` in `OperatingProfile`) receive synthetic heartbeats; real hardware (`LOCKER-01`) communicates strictly via live HTTP requests.
   - `DueReminder` dispatches warning emails 15 minutes prior to `due_at` for accounts with verified email addresses.
2. **`DashboardApi`**: Serves JSON from the cached in-memory snapshot; responds HTTP 503 during cold-boot warmup before the initial snapshot completes.
   `?device=ID` queries per-device analytics.
3. **`dashboard.jsp`**: Server renders the initial view; subsequent updates poll asynchronously via `dashboard.js`, skipping redundant polls while an in-flight request is pending and mutating only changed DOM elements.

---

## Part 2: Locker Rental Lifecycle

### 2.1 Reservation & Access Flow

```mermaid
flowchart TD
    Start(["Sign in / Register"]) --> Map["Locker Map: select available slot"]
    Map --> Form["Select storage plan (2 h, 4 h, Day pass, or Custom 1-23 h / 1-7 days) and access method; pricing scaled by size S/M/L"]
    Form --> Confirm["Confirmation modal: upfront charge, projected balance, cancellation & late fee policies"]
    Confirm --> Reserve{"Deposit_Reserve"}
    Reserve -- "50030 Insufficient balance" --> Err["Localized error message (Web.sqlMessage)"]
    Reserve -- "50046 Remaining balance below 10,000 VND buffer" --> Err
    Reserve -- "50031 >=3 no-shows within 7 days" --> Err
    Reserve -- "50032 Active booking already exists" --> Err
    Reserve -- "50033 Slot just reserved by another user" --> Err
    Reserve -- "50035 Device offline" --> Err
    Reserve -- "50050/50051 Invalid custom duration or missing day plan" --> Err
    Reserve -- "Success" --> Held["RESERVED, 15-minute hold, funds deducted"]
    Held --> Mine["My Locker: PIN or card/fingerprint enrollment code"]
    Mine --> Open1{"First unlock at box (auth) or smartphone (/k/LOCKER-01)"}
    Open1 -- "CHECK_IN" --> Active["ACTIVE, slot OCCUPIED, due_at = unlock time + plan duration (or custom_min)"]
    Held -- "Cancelled within 5 minutes" --> Cancel["CANCELLED, 100% refund"]
    Held -- "Cancelled after 5 min during hold" --> CancelLate["CANCELLED, 50% refund (floored to 100 VND)"]
    Held -- "Stale modal quote" --> Err2["50052: cancellation rejected, refreshed quote displayed"]
    Err2 --> Held
    Held -- "15-minute hold expires without check-in" --> Active["Auto check-in (AUTO_CHECK_IN): ACTIVE, slot remains locked, 0 refund"]
    Active -- "Paid extension (up to 3 times)" --> Active
    Active --> Open2{"Access during rental: box prompts A: Open slot / B: Check out (CHOOSE)"}
    Open2 -- "A: OPEN -> ACCESS, audit ACCESS" --> Active
    Open2 -- "B: CHECKOUT -> PICKUP" --> Done["COMPLETED, slot AVAILABLE"]
    Active -- "Past due_at + grace period" --> Locked["Overdue lock: locked_at set, hourly late fee charged, wallet may go negative"]
    Locked -- "Extension attempt" --> Err3["50048: extensions forbidden while overdue"]
    Locked -- "Access with negative balance" --> Deny["DENY OVERDUE_UNPAID with outstanding debt"]
    Deny -- "Top up and approved" --> Locked
    Locked -- "Access with non-negative balance: PICKUP, overdue_fee assessed" --> Done
    Locked -- "Past due_at by 48 hours" --> Esc["Escalated: escalated_at set, alert OVERDUE_ESCALATED triggered"]
    Esc -- "Pay debt and retrieve belongings (staff remote open fires solenoid; completed on Sessions page)" --> Done
```

**Custom Duration Plans** (`Deposit_Reserve` accepts `@custom_min`, price recomputed server-side by `dbo.fn_CustomPrice`):
1–23 hours (`CUSTOM_MAX_HOURS`) or 1–7 days (`CUSTOM_MAX_DAYS`).
Hourly: `min(hourly_rate * N, day_pass_rate)`. Daily: `day_pass_rate * N * multiplier * size_factor`. Multiplier is 100% for 1 day, 90% for 2–6 days (`CUSTOM_MULTI_DAY_PCT`), 80% for >=7 days (`CUSTOM_WEEK_PCT`).
Overdue lockers never release automatically (`AUTO_RELEASE_OVERDUE` removed from v1/v2): user possessions remain stored inside.

| Custom Plan Duration | S (VND) | M (VND) | L (VND) |
|---|---|---|---|
| 1 hour | 2,500 | 3,300 | 4,300 |
| 3 hours | 7,500 | 9,900 | 12,900 |
| 9 hours | 22,500 | 29,700 | 38,700 |
| 10–23 hours (capped at Day Pass) | 25,000 | 32,500 | 42,300 |
| 1 day | 25,000 | 32,500 | 42,300 |
| 2 days (90%) | 45,000 | 58,500 | 76,100 |
| 3 days (90%) | 67,500 | 87,800 | 114,100 |
| 6 days (90%) | 135,000 | 175,500 | 228,200 |
| 7 days (80%) | 140,000 | 182,000 | 236,600 |

### 2.2 Hardware Authentication (`POST /api/device/auth`)

```mermaid
sequenceDiagram
    participant Box as ESP32 Hardware Box
    participant Api as DeviceAuthApi
    participant Db as Device_Authorize
    Box->>Api: X-API-Key + {"method":"PIN","pin":"...","intent":"ASK"}
    Api->>Api: Format validation (400 if malformed)
    Api->>Db: device_id resolved strictly from API key hash
    Db-->>Api: UNLOCK (CHECK_IN / ACCESS / PICKUP), CHOOSE or DENY + reason
    Api-->>Box: ASCII string for LCD 1602, open_sec, attempts_left, retry_after_sec
    Note over Box: CHOOSE: LCD prompts "A: Open slot / B: Check out", retains PIN/UID/fingerprint
    Box->>Api: Same credential payload, "intent":"OPEN" (key A) or "CHECKOUT" (key B)
    Api-->>Box: UNLOCK ACCESS (booking remains ACTIVE) or UNLOCK PICKUP (booking ends)
```

**Multi-Access Support (v6).** The initial authentication for a `RESERVED` booking triggers `CHECK_IN`. Subsequent authentications during an `ACTIVE` booking with `"intent":"ASK"` respond with `{"result":"CHOOSE",...}`. The box prompts `A: Open slot / B: Check out`.

| `intent` | `RESERVED` Status | `ACTIVE` (On Time) | Overdue (Balance >= 0) | Overdue (Balance < 0) |
|---|---|---|---|---|
| Omitted (legacy firmware) | `UNLOCK CHECK_IN` | `UNLOCK PICKUP` | `UNLOCK PICKUP` | `DENY OVERDUE_UNPAID` |
| `ASK` | `UNLOCK CHECK_IN` | `CHOOSE` | `UNLOCK PICKUP` | `DENY OVERDUE_UNPAID` |
| `OPEN` | `UNLOCK CHECK_IN` | `UNLOCK ACCESS` | `UNLOCK PICKUP` | `DENY OVERDUE_UNPAID` |
| `CHECKOUT` | `UNLOCK CHECK_IN` | `UNLOCK PICKUP` | `UNLOCK PICKUP` | `DENY OVERDUE_UNPAID` |

- `ACCESS`: Booking remains `ACTIVE`, slot stays `OCCUPIED`, due date unchanged. Appends an `ACCESS` audit entry.
- 5 consecutive failed credential attempts enforce a 120-second lockout on that channel.

### 2.3 Slot State Diagram

```mermaid
stateDiagram-v2
    [*] --> AVAILABLE
    AVAILABLE --> RESERVED : Deposit_Reserve
    RESERVED --> AVAILABLE : Cancelled
    RESERVED --> OCCUPIED : 15-min hold expires (Auto check-in)
    OCCUPIED --> AVAILABLE : Due with zero opens (NO_SHOW, no late fee)
    RESERVED --> OCCUPIED : First unlock (CHECK_IN)
    OCCUPIED --> AVAILABLE : Checkout unlock (PICKUP), after debt paid
    OCCUPIED --> OCCUPIED : Overdue lock & late fee assessment
    AVAILABLE --> MAINTENANCE : Ticket opened by staff
    MAINTENANCE --> AVAILABLE : Ticket resolved and closed
```
