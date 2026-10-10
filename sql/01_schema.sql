-- ============================================================
-- 01_schema.sql   SKELETON. The finished script is explained, part by part, in docs/HUONG_DAN_TUNG_FILE.md
-- (section "sql/01_schema.sql"). Write each part, run the file, fix the errors, then go on to the next part.
-- The file must run again and again from the top: it drops and recreates the database.
-- ============================================================

-- ===== Part A. Database =====
-- TODO A1: USE master, drop PRJ301_LOCKER if it exists (SINGLE_USER WITH ROLLBACK IMMEDIATE first), create it, USE it.
-- TODO A2: SET QUOTED_IDENTIFIER ON and SET ANSI_NULLS ON (filtered indexes need them).


-- ===== Part B. The 14 shared tables of the assignment =====
-- Copy them from De-01_locker.docx, Workshop 1, step 2:
-- Users, Roles, UserRole, Permissions, RolePerm, Device, SensorType, Calibration, OperatingProfile,
-- Alert, AlertEvidence, MaintenanceTicket, AuditLog, HashChain.
-- TODO B1: paste them, read every column, and run.


-- ===== Part C. The 4 tables of the topic =====
-- From the same step: LockerSession, LockerSessionLabel, LockerSessionReading, LockerSlot,
-- the trigger trg_LockerSession_AppendOnly (sessions are never updated or deleted).
-- TODO C1: paste them. Remember GO before CREATE TRIGGER.


-- ===== Part D. Our additions =====
-- TODO D1: LockerArea(area_id, area_code unique, name, location, is_active)
-- TODO D2: LockerBank(bank_id, bank_code unique, name, area_id -> LockerArea, device_id -> Device nullable and unique when
--          not null, door_rows, status)
-- TODO D3: ALTER Users ADD email, phone, area_id -> LockerArea; unique index on email where not null.
--          A column added by ALTER cannot be used in the same batch: put GO in between.
-- TODO D4: ALTER Roles ADD rank_no (1 = ADMIN ... 5 = END_USER).
-- TODO D5: LockerSlot: slot_code, bank_id, status NOT NULL; add size_code (S, M, L), foreign key to LockerBank,
--          UNIQUE (bank_id, slot_code), CHECK on status.
-- TODO D6: ALTER LockerSession ADD slot_id (FK), card_uid, open_source, command_id (NO foreign key on command_id: a forged id
--          must still be stored as evidence).
-- TODO D7: UserCard(card_id, card_uid unique, user_id, status ACTIVE/LOST/BLOCKED, issued_at, lost_at)
-- TODO D8: StoragePlan(plan_id, plan_name, duration_min, grace_min, price, is_active)
-- TODO D9: Deposit(deposit_id, user_id, slot_id, plan_id, card_id, status, reserved_at, hold_until, started_at, due_at, ended_at,
--          extend_count) with CHECK on status and two filtered unique indexes: one open booking per slot, one per user.
-- TODO D10: RemoteCommand(command_id, device_id, slot_id, action, reason, requested_by, status PENDING/SENT/DONE/EXPIRED,
--           created_at, expires_at, done_at, session_id)


-- ===== Part E. Views =====
-- TODO E1: v_LockerSession_Features: the sessions that have a label, minus REMOTE sessions and sessions with a SENSOR_FAULT alert.
-- TODO E2: v_LockerSlotMap: one row per slot with display_status = OFFLINE, MAINTENANCE, ALERT, OVERDUE or the slot status.
--          The order of the CASE branches decides which colour wins.


-- ===== Part F. Audit_Append =====
-- TODO F1: the procedure of Workshop 2, step 4. It inserts the AuditLog row and chains its hash in one transaction.
--          Hash the text  id|ts|actor|action|objectType|objectId|diff|prevHash  with SHA2_256.


-- ===== Part G. Seed data =====
-- TODO G1: Roles with rank_no, Permissions (every resource READ and WRITE), RolePerm (the matrix of the guide).
-- TODO G2: LockerArea LIB, DOMA, CANT, GYM, OPS; Device LOCKER-01 with api_key_hash = SHA-256 of 'device-1-api-key' (VARCHAR, not N'').
-- TODO G3: LockerBank, LockerSlot (90 doors), a few tall doors.
-- TODO G4: Users. The user 'system' MUST be the first row (user_id = 1). The others use a BCrypt hash of 123456.
--          Generate the hash with a few lines of Java (see the guide, section util/SecurityUtils).
-- TODO G5: UserRole, StoragePlan, SensorType (DOOR, WEIGHT, STAY), one WEIGHT Calibration, UserCard, two Deposits.
-- TODO G6: EXEC Audit_Append for the first row of the chain.
