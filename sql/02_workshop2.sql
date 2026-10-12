-- ============================================================
-- 02_workshop2.sql  The public data set (TON_IoT garage door) turned into sessions.
-- Run it in two rounds: part 1 now, then import the csv, then part 2.
-- Source of the file: research.unsw.edu.au/projects/toniot-datasets, folder Train_Test_datasets,
-- file Train_Test_IoT_Garage_Door.csv
-- ============================================================
USE PRJ301_LOCKER;
GO

-- ===== Part 1. The table the sessions go into =====
-- Same feature names as the device sends, so the model trained here can score device sessions.
CREATE TABLE PublicSession (
    public_id      INT IDENTITY PRIMARY KEY,
    door_open_sec  FLOAT,
    weight_delta_g FLOAT,
    unlock_count   INT,
    rfid_ok        BIT,
    stay_min       FLOAT,
    label          NVARCHAR(40),
    sent           BIT DEFAULT 0);
GO

-- ===== Import the csv =====
-- In SSMS: right click the database PRJ301_LOCKER, Tasks, Import Flat File, choose the csv and
-- type RawGarageDoor as the table name. Do NOT create RawGarageDoor yourself, the wizard creates it.
-- Then look at what it made, the query of part 2 needs the columns door_state and label:
--     SELECT TOP 10 * FROM RawGarageDoor;
--     SELECT label, COUNT(*) FROM RawGarageDoor GROUP BY label;
-- If the names differ in your file, change them in part 2.

-- ===== Part 2. Group the rows into sessions =====
-- Every 20 consecutive rows become one simulated session; a row is about 3 seconds.
-- A session is NORMAL when none of its rows is an attack, FORCED_OPEN otherwise.
-- ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) keeps no real order. If the file has date and time columns,
-- put them in the ORDER BY: ORDER BY [date], [time].
WITH numbered AS (
    SELECT *, (ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1) / 20 AS session_no
    FROM RawGarageDoor
)
INSERT INTO PublicSession (door_open_sec, weight_delta_g, unlock_count, rfid_ok, stay_min, label)
SELECT SUM(CASE WHEN door_state = 'open' THEN 3 ELSE 0 END),          -- seconds with the door open
       0,                                                              -- the public data has no weight
       COUNT(*),                                                       -- 20, a placeholder for unlock_count
       MIN(CASE WHEN label = 0 THEN 1 ELSE 0 END),                     -- 1 only if every row is normal
       20.0,
       CASE WHEN MAX(label) = 0 THEN 'NORMAL' ELSE 'FORCED_OPEN' END
FROM numbered
GROUP BY session_no;
GO

-- ===== Check. A few hundred sessions and a few dozen of each label are needed for the training to mean anything =====
SELECT COUNT(*) AS total_sessions FROM PublicSession;
SELECT label, COUNT(*) AS n FROM PublicSession GROUP BY label ORDER BY n DESC;
GO
