-- ============================================================
-- 02_workshop2.sql   SKELETON. Explained in docs/HUONG_DAN_TUNG_FILE.md, section "sql/02_workshop2.sql".
-- The public data set (TON_IoT garage door) turned into sessions for the machine learning step.
-- ============================================================

-- ===== Part 1. Table for the sessions =====
-- TODO 1: PublicSession(public_id identity, door_open_sec, weight_delta_g, unlock_count, rfid_ok, stay_min, label, sent).
--         The feature names are the ones the device sends.

-- ===== Import =====
-- TODO 2: download Train_Test_IoT_Garage_Door.csv from research.unsw.edu.au/projects/toniot-datasets (Train_Test_datasets).
--         SSMS: Tasks > Import Flat File, table name RawGarageDoor. Do not create the table yourself.
--         Look at it: SELECT TOP 10 * FROM RawGarageDoor; SELECT label, COUNT(*) FROM RawGarageDoor GROUP BY label;

-- ===== Part 2. Group rows into sessions =====
-- TODO 3: a CTE that numbers the rows, session_no = (row number - 1) / 20; INSERT one PublicSession per session_no:
--         door_open_sec = 3 seconds per row with door_state = 'open', rfid_ok = 1 only if no row is an attack,
--         label = NORMAL or FORCED_OPEN.
-- TODO 4: check: how many sessions, how many of each label. A few hundred sessions are the minimum.
