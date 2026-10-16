# SmartLocker System Architecture & Business Flows

This document details the core data pipelines and business lifecycles of the **SmartLocker** IoT Management System, covering both the Real-Time Telemetry Pipeline and the End-to-End User Booking Lifecycle.

---

## Part 1: Real-Time IoT Dashboard Pipeline

### 1.1 High-Concurrency Architecture

To support high-frequency client polling without degrading database throughput, the system employs an **In-Memory Snapshot Cache** managed by a dedicated daemon thread.

```mermaid
flowchart TD
    DB[(SQL Server DB)] -->|Aggregated query every 2s| LM["LockerMonitor (Daemon Scheduler)"]
    LM -->|Atomic swap| CACHE["AtomicReference&lt;DashboardSnapshot&gt;"]
    
    subgraph ReadPath ["Non-Blocking Read Path"]
        API["DashboardApi (/api/dashboard)"] -->|Zero DB Queries| CACHE
        API -->|JSON with Cache-Control: no-store| Client["dashboard.jsp (Vanilla JS Engine)"]
    end
    
    subgraph ClientEngine ["Client-side Polling Engine"]
        Client -->|Recursive setTimeout + AbortController| API
        Client -->|Differential DOM Updates| UI["Bento KPI Cards & Live Matrices"]
    end
```

### 1.2 Pipeline Components
1. **`LockerMonitor` (Daemon Background Scheduler):**
   - Refreshes a `DashboardSnapshot` object every 2 seconds.
   - Evaluates slot status counts in a single query via `SUM(CASE WHEN...)` on `v_LockerSlotMap`.
   - Checks the cryptographic integrity of the audit hash chain (`AuditVerifier`).
   - Keeps active demo bank controllers alive with periodic keep-alive pings.
2. **`DashboardApi` (`/api/dashboard`):**
   - High-performance, read-only endpoint.
   - Fetches the snapshot reference directly from memory in $< 1\text{ ms}$.
   - Serializes payload using `Gson` with null safety.
3. **`dashboard.jsp` (Client Real-Time Engine):**
   - **Server-Side Rendering (SSR):** Initial state rendered server-side to prevent UI flicker (`—`).
   - **Non-overlapping Polling:** Recursive `setTimeout` guarantees that a new request is dispatched only after the previous request settles.
   - **Stray Service Worker Immunity:** Automatically unregisters stale localhost workers that intercept network requests.
   - **Differential DOM Updates:** Only DOM nodes whose values changed trigger reflow and animations.

---

## Part 2: End-to-End Locker Lifecycle & Scenario Matrix

### 2.1 Complete Flowchart (Registration to Return)

```mermaid
flowchart TD
    Start(["User Registration"]) --> RegVerify{"Username Unique & Valid?"}
    RegVerify -- "Duplicate / Invalid" --> RegError["Show validation error"]
    RegError --> Start
    RegVerify -- "Valid" --> AccCreated["Create Account (Role: END_USER, Balance: 0)"]
    
    AccCreated --> Login["Sign In (LoginController)"]
    Login --> ChkBalance{"Wallet Balance >= Plan Price?"}
    
    ChkBalance -- "No" --> TopupFlow["Top-up via VietQR / Transfer"]
    TopupFlow --> AdminReview["Staff Approval / Auto-Credit"]
    AdminReview --> ChkBalance
    
    ChkBalance -- "Yes" --> BrowseMap["Explore Locker Map & Select Available Slot"]
    BrowseMap --> ReserveCall{"Execute Deposit_Reserve"}
    
    ReserveCall -- "Balance < Price" --> Err30["Error 50030: Insufficient balance"]
    ReserveCall -- "Active Booking Exists" --> Err32["Error 50032: Booking already in progress"]
    ReserveCall -- ">= 3 No-Shows in 7d" --> Err31["Error 50031: Booking blocked"]
    ReserveCall -- "Locker Offline" --> Err35["Error 50035: Locker is offline"]
    ReserveCall -- "Slot Race Conflict" --> Err33["Error 50033: Slot no longer available"]
    
    ReserveCall -- "Success" --> ReservedState["Slot: RESERVED (15-min Hold Window)"]
    
    ReservedState --> CheckInDecision{"Customer arrives within 15 mins?"}
    
    CheckInDecision -- "Customer Cancels (Deposit_Cancel)" --> Refund["Refund 100% deposit -> Slot: AVAILABLE"]
    CheckInDecision -- "Hold Expires (Deposit_ExpireNoShow)" --> NoShow["Mark NO_SHOW, refund full deposit -> Slot: AVAILABLE"]
    CheckInDecision -- "Customer Check-In (Deposit_CheckIn)" --> ActiveState["Slot: OCCUPIED (Status: ACTIVE)"]
    
    ActiveState --> InUseEvents{"Events During Session"}
    InUseEvents -- "Extend Time (Deposit_Extend)" --> ExtendSlot["Add 15-240 mins (Max 3 times)"]
    ExtendSlot --> ActiveState
    InUseEvents -- "Report Lost Card" --> BlockOld["Block old RFID card & bind new card"]
    BlockOld --> ActiveState
    InUseEvents -- "Door Tamper / Sensor Fault" --> AIAlert["RiskScorer & Rule Engine raise CRITICAL Alert"]
    AIAlert --> ActiveState
    
    ActiveState --> CheckOut{"Session Completion (Check-out)"}
    CheckOut -- "Normal Retrieval (due_at >= now)" --> CompleteNormal["Sensors detect empty slot (Deposit_Complete)"]
    CheckOut -- "Overdue Retrieval (due_at < now)" --> OverdueState["Slot: OVERDUE (Auto-Release / Penalty)"]
    
    CompleteNormal --> AvailableAgain["Slot returned to AVAILABLE (Green)"]
    OverdueState --> AvailableAgain
    AvailableAgain --> Finish(["Ready for next customer"])
```

---

### 2.2 Scenario Handling Matrix

| Scenario Code | Trigger Condition | System Action | Resulting State |
| :--- | :--- | :--- | :--- |
| **Case 2.1: Happy Reserve** | Balance $\ge$ Plan price, slot is `AVAILABLE`, controller `ACTIVE`. | Atomically debits balance, sets slot to `RESERVED`, sets 15-minute hold. | `Deposit.RESERVED`, `Slot.RESERVED` |
| **Case 2.2: Insufficient Funds** | Balance $<$ Plan price. | Aborts transaction, rolls back, returns user-friendly error message. | No state change |
| **Case 2.3: Single Active Limit** | User already has an active or reserved booking. | Prevents double-booking via check on `Deposit(status IN ('RESERVED','ACTIVE'))`. | No state change |
| **Case 2.4: No-Show Ban** | User incurred $\ge 3$ No-Show events within the past 7 days. | Temporarily suspends booking privileges to prevent slot hoarding. | Request rejected |
| **Case 2.5: Hardware Offline** | Device heartbeats stopped ($> 24\text{ h}$). | Flags all child slots as `OFFLINE`; booking disallowed until back online. | Slot disabled |
| **Case 3.1: Active Check-In** | User scans card or places belongings in locker within 15 minutes. | Transition session to `ACTIVE`, start duration countdown (`due_at = now + plan_min`). | `Deposit.ACTIVE`, `Slot.OCCUPIED` |
| **Case 3.2: User Cancellation** | User clicks Cancel before check-in. | Refunds full fee to balance, releases slot lock immediately. | `Deposit.CANCELLED`, `Slot.AVAILABLE` |
| **Case 3.3: Hold Expiry (No-Show)**| 15 minutes elapse without sensor or RFID activity. | `LockerMonitor` executes `Deposit_ExpireNoShow`: releases slot, refunds balance, logs audit. | `Deposit.NO_SHOW`, `Slot.AVAILABLE` |
| **Case 4.1: Online Extension** | User requests more time before expiration. | Adds 15 to 240 minutes to `due_at` (allowed at most 3 times per booking). | `Deposit.ACTIVE` (`extend_count += 1`) |
| **Case 4.2: Lost Card Security** | User reports RFID badge lost or compromised. | Marks card `BLOCKED`; pushes blocked UID to device heartbeat blacklist; re-binds booking to replacement card. | Card blacklisted |
| **Case 4.3: Tamper Detection** | Door opened without RFID authorization or weight anomaly detected. | Weka ML `RiskScorer` flags anomaly ($Risk \ge 0.70$); triggers `CRITICAL` alert on dashboard. | Alert created, Technician notified |
| **Case 5.1: Normal Return** | User removes belongings, sensors record weight $\approx 0\text{ g}$, door closes. | Heartbeat executes `Deposit_Complete`: ends session, frees slot. | `Deposit.COMPLETED`, `Slot.AVAILABLE` |
| **Case 5.2: Overdue Auto-Release** | `due_at` has elapsed without locker retrieval. | Slot displays `OVERDUE` (orange/red); `Deposit_ExpireOverdue` releases slot to prevent deadlocks. | `Deposit.COMPLETED`, `Slot.AVAILABLE` |

---

### 2.3 State Machine Diagram

```mermaid
stateDiagram-v2
    [*] --> AVAILABLE : System Initialization / Slot Reset
    
    AVAILABLE --> RESERVED : Deposit_Reserve (Balance debited, 15m hold)
    
    RESERVED --> AVAILABLE : Deposit_Cancel (User cancels, fee refunded)
    RESERVED --> AVAILABLE : Deposit_ExpireNoShow (15m elapsed, fee refunded)
    
    RESERVED --> OCCUPIED : Deposit_CheckIn (Belongings detected / RFID swipe)
    
    OCCUPIED --> OCCUPIED : Deposit_Extend (Extension granted, max 3 times)
    OCCUPIED --> OVERDUE : due_at elapsed without check-out
    
    OCCUPIED --> AVAILABLE : Deposit_Complete (Items removed on time)
    OVERDUE --> AVAILABLE : Deposit_ExpireOverdue (Auto-release or penalty settled)
    
    AVAILABLE --> MAINTENANCE : Hardware fault / Operator flag
    OCCUPIED --> MAINTENANCE : Critical sensor anomaly / Lock failure
    MAINTENANCE --> AVAILABLE : Technician resolves ticket
```
