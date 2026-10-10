-- ============================================================
-- 03_scenarios.sql   SKELETON. Explained in docs/HUONG_DAN_TUNG_FILE.md, section "sql/03_scenarios.sql".
-- Stored procedures of the 5 real-life cases. Use CREATE OR ALTER so the file can run again.
-- Every procedure ends with EXEC Audit_Append. Automatic work is done by the user 'system'
-- (SELECT user_id FROM Users WHERE username = N'system').
-- The Java side calls them with CallableStatement, the signatures below are the contract with the DAO classes.
-- ============================================================

-- ===== Case 1. A locker goes offline =====
-- TODO 1.1  Device_Heartbeat @device_id INT
--           last_seen = now; an OFFLINE device becomes ACTIVE (a MAINTENANCE device stays); its DEVICE_OFFLINE alerts are RESOLVED.
-- TODO 1.2  Device_MarkOffline @timeout_sec INT = 60
--           ACTIVE devices not seen for @timeout_sec become OFFLINE, each gets one DEVICE_OFFLINE alert with evidence last_seen_utc.

-- ===== Case 2. Staff opens a slot from the web =====
-- TODO 2.1  RemoteCommand_Create @slot_id INT, @reason NVARCHAR(200), @actor INT, @new_id BIGINT OUTPUT
--           THROW 50010 no device, 50011 device not ACTIVE, 50012 another operator controls it, 50013 reason shorter than 5.
--           The command expires after 2 minutes.
-- TODO 2.2  RemoteCommand_TakePending @device_id INT      (UPDATE ... OUTPUT: PENDING -> SENT, returns command_id, slot_code, action)
-- TODO 2.3  RemoteCommand_Expire                          (PENDING commands past expires_at -> EXPIRED; never touch SENT)

-- ===== Case 3. A card is lost =====
-- TODO 3.1  UserCard_ReportLost @card_id INT, @actor INT   (only the owner, only an ACTIVE card, else THROW 50020)
-- TODO 3.2  UserCard_Replace @old_card_id INT, @new_uid NVARCHAR(32), @actor INT, @new_card_id INT OUTPUT
--           THROW 50021 unless the old card is not ACTIVE; the open booking moves to the new card.

-- ===== Case 4. Booking a slot, and not coming =====
-- TODO 4.1  Deposit_Reserve @user_id INT, @slot_id INT, @plan_id INT, @new_id BIGINT OUTPUT
--           50030 no active card, 50031 three no-shows in 7 days, 50032 a booking is already open, 50033 slot taken,
--           50034 plan not available, 50035 device offline. The slot is locked by UPDATE ... WHERE status = 'AVAILABLE'.
--           Hold the slot 15 minutes (hold_until).
-- TODO 4.2  Deposit_Cancel @deposit_id BIGINT, @actor INT              (50036)
-- TODO 4.3  Deposit_Extend @deposit_id BIGINT, @minutes INT, @actor INT (50037 minutes 15..240, 50038 not yours, 50039 third extension used)
-- TODO 4.4  Deposit_CheckIn @device_id INT, @slot_code NVARCHAR(20)     (RESERVED -> ACTIVE, start the clock, slot OCCUPIED)
-- TODO 4.5  Deposit_Complete @device_id INT, @slot_code NVARCHAR(20)    (ACTIVE -> COMPLETED, slot AVAILABLE unless MAINTENANCE)
-- TODO 4.6  Deposit_ExpireNoShow                                        (RESERVED past hold_until -> NO_SHOW, slot AVAILABLE;
--                                                                        a booking on an OFFLINE device is not judged)

-- ===== Case 5. A sensor breaks =====
-- TODO 5.1  Ticket_OpenForFault @device_id INT, @alert_id INT, @session_id BIGINT, @note NVARCHAR(400)
--           the slot of the session goes to MAINTENANCE; one OPEN ticket per device, given to the least busy technician.
-- TODO 5.2  Ticket_Close @ticket_id INT, @actor INT, @note NVARCHAR(400) = NULL   (50040; slot AVAILABLE, alert RESOLVED)
-- TODO 5.3  Alert_Resolve @alert_id INT, @actor INT                                (50041)
