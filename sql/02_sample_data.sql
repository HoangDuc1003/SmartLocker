-- 02_sample_data.sql: consolidated demo users, telemetry and special cases.
-- Run 01 -> 02 -> 03 -> 04 for a fresh setup. Run only 02 to add this demo
-- to an existing current schema. DEMO_DATA_V2 prevents duplicate seed batches.
-- All generated telemetry is synthetic; it is not the TON_IoT research dataset.
USE PRJ301_LOCKER;
GO
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
SET XACT_ABORT ON;
GO
IF COL_LENGTH('dbo.RemoteCommand', 'sent_at') IS NULL
    ALTER TABLE dbo.RemoteCommand ADD sent_at DATETIME2 NULL;
GO
IF OBJECT_ID(N'dbo.PublicSession', N'U') IS NULL
    CREATE TABLE dbo.PublicSession (
        public_id INT IDENTITY PRIMARY KEY,
        door_open_sec FLOAT, weight_delta_g FLOAT, unlock_count INT,
        rfid_ok BIT, stay_min FLOAT, label NVARCHAR(40), sent BIT DEFAULT 0);
GO

-- Optional TON_IoT CSV import: import the CSV as RawGarageDoor with door_state
-- and label columns, then rerun this file. Existing PublicSession rows are kept.
IF OBJECT_ID(N'dbo.RawGarageDoor', N'U') IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM dbo.PublicSession)
    EXEC(N'WITH numbered AS (
        SELECT *, (ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1) / 20 AS session_no
        FROM dbo.RawGarageDoor)
    INSERT INTO dbo.PublicSession (door_open_sec, weight_delta_g, unlock_count, rfid_ok, stay_min, label)
    SELECT SUM(CASE WHEN door_state = ''open'' THEN 3 ELSE 0 END), 0, COUNT(*),
           MIN(CASE WHEN label = 0 THEN 1 ELSE 0 END), 20.0,
           CASE WHEN MAX(label) = 0 THEN ''NORMAL'' ELSE ''FORCED_OPEN'' END
    FROM numbered GROUP BY session_no;');
GO

BEGIN TRY
    BEGIN TRANSACTION;
    IF EXISTS (SELECT 1 FROM dbo.AuditLog WITH (UPDLOCK, HOLDLOCK)
               WHERE action = N'SEED' AND diff_json = N'DEMO_DATA_V2')
    BEGIN
        COMMIT;
        PRINT 'DEMO_DATA_V2 already loaded; existing demo state was preserved.';
        RETURN;
    END;

    DECLARE @now DATETIME2 = SYSUTCDATETIME();
    DECLARE @admin INT = (SELECT user_id FROM dbo.Users WHERE username = N'admin');
    DECLARE @operator INT = (SELECT user_id FROM dbo.Users WHERE username = N'operator1');
    DECLARE @tech1 INT = (SELECT user_id FROM dbo.Users WHERE username = N'tech1');
    DECLARE @tech2 INT = (SELECT user_id FROM dbo.Users WHERE username = N'tech2');
    DECLARE @weight INT = (SELECT sensor_type_id FROM dbo.SensorType WHERE name = N'WEIGHT');
    DECLARE @numbers TABLE (n INT PRIMARY KEY);
    ;WITH nums AS (SELECT 1 n UNION ALL SELECT n + 1 FROM nums WHERE n < 500)
    INSERT INTO @numbers SELECT n FROM nums OPTION (MAXRECURSION 500);

    -- 1. 100 visible user accounts, plus the disabled system account.
    -- The baseline provides 16 user accounts; 83 students + user1 bring it to 100.
    DECLARE @users TABLE (n INT PRIMARY KEY, username NVARCHAR(50));
    INSERT INTO @users SELECT n, N'student' + CONVERT(NVARCHAR(3), n)
    FROM @numbers WHERE n BETWEEN 9 AND 91;
    INSERT INTO @users VALUES (0, N'user1');
    INSERT INTO dbo.Users (username, password_hash, full_name, email, phone, area_id, status, created_at, balance)
    SELECT d.username, '$2a$10$iz5TJTP.i9YQlKBSU4GzKO.rbQIU.PocHFDv24b8Xsfm8hC2Rwp3m',
        CASE d.n % 10
            WHEN 0 THEN N'Nguyễn' WHEN 1 THEN N'Trần' WHEN 2 THEN N'Lê'
            WHEN 3 THEN N'Phạm' WHEN 4 THEN N'Hoàng' WHEN 5 THEN N'Vũ'
            WHEN 6 THEN N'Đặng' WHEN 7 THEN N'Bùi' WHEN 8 THEN N'Đỗ' ELSE N'Ngô' END
        + N' ' + CASE (d.n / 10) % 9
            WHEN 0 THEN N'Minh Anh' WHEN 1 THEN N'Quốc Bảo' WHEN 2 THEN N'Thu Hà'
            WHEN 3 THEN N'Hoàng Nam' WHEN 4 THEN N'Ngọc Linh' WHEN 5 THEN N'Gia Huy'
            WHEN 6 THEN N'Bảo Trâm' WHEN 7 THEN N'Thanh Tùng' ELSE N'Khánh Vy' END,
        d.username + N'@smartlocker.edu.vn',
        N'092' + RIGHT(N'0000000' + CONVERT(NVARCHAR(7), d.n), 7), a.area_id,
        N'ACTIVE', DATEADD(DAY, -(d.n % 60), @now), 50000 + (d.n % 6) * 50000
    FROM @users d JOIN dbo.LockerArea a ON a.area_code = CASE d.n % 4
        WHEN 0 THEN N'LIB' WHEN 1 THEN N'DOMA' WHEN 2 THEN N'CANT' ELSE N'GYM' END
    WHERE NOT EXISTS (SELECT 1 FROM dbo.Users u WHERE u.username = d.username);
    INSERT INTO dbo.UserRole (user_id, role_id)
    SELECT u.user_id, r.role_id FROM @users d JOIN dbo.Users u ON u.username = d.username
    JOIN dbo.Roles r ON r.role_name = N'END_USER'
    WHERE NOT EXISTS (SELECT 1 FROM dbo.UserRole ur WHERE ur.user_id = u.user_id);
    UPDATE dbo.Users SET balance = 100000 WHERE username IN
        (N'student1',N'student2',N'student3',N'student4',N'student5',N'student6',N'student7',N'student8') AND balance = 0;
    UPDATE dbo.Users SET balance = 500000 WHERE username = N'admin' AND balance = 0;
    UPDATE dbo.Users SET balance = 200000 WHERE username = N'user1' AND balance = 0;
    UPDATE dbo.Users SET balance = 0 WHERE username = N'student88';
    UPDATE dbo.Users SET balance = 1000 WHERE username = N'student87';
    UPDATE dbo.Users SET status = N'LOCKED' WHERE username = N'student90';
    UPDATE dbo.Users SET status = N'DISABLED' WHERE username = N'student89';

    -- 2. RFID cards, including a lost card with a replacement and a blocked card.
    INSERT INTO dbo.UserCard (card_uid, user_id)
    SELECT N'04DE' + RIGHT(N'0000' + CONVERT(NVARCHAR(4), d.n), 4), u.user_id
    FROM @users d JOIN dbo.Users u ON u.username = d.username
    WHERE NOT EXISTS (SELECT 1 FROM dbo.UserCard c WHERE c.user_id = u.user_id)
      AND NOT EXISTS (SELECT 1 FROM dbo.UserCard c
          WHERE c.card_uid = N'04DE' + RIGHT(N'0000' + CONVERT(NVARCHAR(4), d.n), 4));
    INSERT INTO dbo.UserCard (card_uid, user_id)
    SELECT v.uid, u.user_id FROM (VALUES
        (N'04F5A6B7',N'student4'),(N'04556677',N'student5'),(N'04778899',N'student6'),
        (N'04334455',N'student8')) v(uid, username)
    JOIN dbo.Users u ON u.username = v.username
    WHERE NOT EXISTS (SELECT 1 FROM dbo.UserCard c WHERE c.card_uid = v.uid);
    UPDATE c SET status = N'LOST', lost_at = DATEADD(HOUR,-3,@now)
    FROM dbo.UserCard c JOIN dbo.Users u ON u.user_id=c.user_id
    WHERE u.username=N'student12' AND c.card_uid=N'04DE0012';
    UPDATE c SET status = N'BLOCKED'
    FROM dbo.UserCard c JOIN dbo.Users u ON u.user_id=c.user_id
    WHERE u.username=N'student13' AND c.status=N'ACTIVE';
    INSERT INTO dbo.UserCard (card_uid,user_id,issued_at)
    SELECT N'04FF0012',u.user_id,DATEADD(HOUR,-2,@now) FROM dbo.Users u
    WHERE u.username=N'student12' AND NOT EXISTS
        (SELECT 1 FROM dbo.UserCard WHERE card_uid=N'04FF0012');

    -- 3. Seven devices linked by bank codes, without relying on identity values.
    DECLARE @devices TABLE (n INT, code NVARCHAR(30), bank NVARCHAR(20));
    INSERT INTO @devices VALUES (1,N'LOCKER-01',N'LIB-A'),(2,N'LOCKER-02',N'LIB-B'),
        (3,N'LOCKER-03',N'DOMA-A'),(4,N'LOCKER-04',N'DOMA-B'),
        (5,N'LOCKER-05',N'CANT-A'),(6,N'LOCKER-06',N'GYM-A'),(7,N'LOCKER-07',N'GYM-B');
    INSERT INTO dbo.Device (device_code,location,firmware,status,last_seen,api_key_hash)
    SELECT v.code,a.location,N'1.1-demo',N'ACTIVE',@now,
        LOWER(CONVERT(CHAR(64),HASHBYTES('SHA2_256','device-'+CONVERT(VARCHAR(2),v.n)+'-api-key'),2))
    FROM @devices v JOIN dbo.LockerBank b ON b.bank_code=v.bank
    JOIN dbo.LockerArea a ON a.area_id=b.area_id
    WHERE NOT EXISTS (SELECT 1 FROM dbo.Device d WHERE d.device_code=v.code);
    UPDATE b SET device_id=d.device_id FROM dbo.LockerBank b
    JOIN @devices v ON v.bank=b.bank_code JOIN dbo.Device d ON d.device_code=v.code;
    UPDATE d SET status=N'ACTIVE',last_seen=@now FROM dbo.Device d JOIN @devices v ON v.code=d.device_code;
    UPDATE dbo.Device SET control_owner=@operator WHERE device_code=N'LOCKER-02';
    UPDATE dbo.Device SET status=N'MAINTENANCE' WHERE device_code=N'LOCKER-04';
    UPDATE dbo.Device SET status=N'OFFLINE',last_seen=DATEADD(HOUR,-26,@now) WHERE device_code=N'LOCKER-07';
    INSERT INTO dbo.Calibration (device_id,sensor_type_id,offset_val,scale_val,version,valid_until,created_by)
    SELECT d.device_id,@weight,0,1,1,DATEADD(MONTH,6,CAST(@now AS DATE)),@admin
    FROM dbo.Device d JOIN @devices v ON v.code=d.device_code
    WHERE NOT EXISTS (SELECT 1 FROM dbo.Calibration c WHERE c.device_id=d.device_id AND c.sensor_type_id=@weight);
    UPDATE c SET valid_until=DATEADD(DAY,-1,CAST(@now AS DATE))
    FROM dbo.Calibration c JOIN dbo.Device d ON d.device_id=c.device_id
    WHERE d.device_code=N'LOCKER-04' AND c.sensor_type_id=@weight;
    INSERT INTO dbo.OperatingProfile (device_id,params_json,updated_by,updated_at)
    SELECT d.device_id,N'{"demo":true,"heartbeat_sec":10,"offline_timeout_sec":86400,"item_left_g":50}',@admin,@now
    FROM dbo.Device d JOIN @devices v ON v.code=d.device_code
    WHERE NOT EXISTS (SELECT 1 FROM dbo.OperatingProfile p WHERE p.device_id=d.device_id);
    INSERT INTO dbo.StoragePlan (plan_name,duration_min,grace_min,price,is_active)
    SELECT v.name,v.duration,v.grace,v.price,v.active FROM (VALUES
        (N'Day pass',480,20,18000,1),(N'Overnight',1440,30,35000,1),
        (N'Archived weekend plan',2880,30,60000,0)) v(name,duration,grace,price,active)
    WHERE NOT EXISTS (SELECT 1 FROM dbo.StoragePlan p WHERE p.plan_name=v.name);

    -- 4. Fifty top-ups: pending, credited once, and rejected.
    DECLARE @newTopups TABLE (user_id INT,amount BIGINT,status NVARCHAR(20));
    INSERT INTO dbo.TopupRequest (user_id,amount,transfer_code,qr_url,status,created_at,approved_at,approved_by,note)
    OUTPUT inserted.user_id,inserted.amount,inserted.status INTO @newTopups
    SELECT u.user_id,50000+(n.n%5)*50000,N'DEMO-V2-TOPUP-'+RIGHT(N'000'+CONVERT(NVARCHAR(3),n.n),3),
        N'https://img.vietqr.io/image/MB-0901000001-compact2.png',
        CASE n.n%5 WHEN 0 THEN N'PENDING' WHEN 1 THEN N'REJECTED' ELSE N'APPROVED' END,
        DATEADD(DAY,-(1+n.n%14),@now),
        CASE WHEN n.n%5=0 THEN NULL ELSE DATEADD(HOUR,1,DATEADD(DAY,-(1+n.n%14),@now)) END,
        CASE WHEN n.n%5=0 THEN NULL ELSE @operator END,
        CASE n.n%5 WHEN 0 THEN N'Chờ đối soát giao dịch mẫu'
            WHEN 1 THEN N'Từ chối: nội dung hoặc số tiền chuyển khoản không khớp'
            ELSE N'Đã đối soát và cộng tiền vào ví mẫu' END
    FROM @numbers n JOIN dbo.Users u ON u.username=N'student'+CONVERT(NVARCHAR(3),n.n+20)
    WHERE n.n<=50 AND NOT EXISTS (SELECT 1 FROM dbo.TopupRequest t
        WHERE t.transfer_code=N'DEMO-V2-TOPUP-'+RIGHT(N'000'+CONVERT(NVARCHAR(3),n.n),3));
    UPDATE u SET balance=balance+x.amount FROM dbo.Users u JOIN
        (SELECT user_id,SUM(amount) amount FROM @newTopups WHERE status=N'APPROVED' GROUP BY user_id) x ON x.user_id=u.user_id;

    -- 5. History: 40 completed rentals, 20 cancellations, 10 no-shows.
    -- The last three no-shows belong to student10 and block new bookings for 7 days.
    DECLARE @history TABLE (n INT,user_id INT,slot_id INT,plan_id INT,status NVARCHAR(20));
    INSERT INTO @history
    SELECT n.n,u.user_id,s.locker_slot_id,p.plan_id,
        CASE WHEN n.n<=40 THEN N'COMPLETED' WHEN n.n<=60 THEN N'CANCELLED' ELSE N'NO_SHOW' END
    FROM @numbers n JOIN dbo.Users u ON u.username=N'student'+CONVERT(NVARCHAR(3),CASE WHEN n.n>=68 THEN 10 ELSE 30+(n.n%40) END)
    JOIN dbo.LockerBank b ON b.bank_code=N'DOMA-A'
    JOIN dbo.LockerSlot s ON s.bank_id=b.bank_id AND s.slot_code=N'A'+RIGHT(N'0'+CONVERT(NVARCHAR(2),1+n.n%20),2)
    JOIN dbo.StoragePlan p ON p.plan_name=N'2 hours'
    WHERE n.n<=70;
    INSERT INTO dbo.Deposit (user_id,slot_id,plan_id,paid_amount,status,reserved_at,hold_until,started_at,due_at,ended_at)
    SELECT h.user_id,h.slot_id,h.plan_id,5000,h.status,
        DATEADD(DAY,-CASE WHEN h.n>=68 THEN h.n-67 ELSE 8+h.n%20 END,@now),
        DATEADD(MINUTE,15,DATEADD(DAY,-CASE WHEN h.n>=68 THEN h.n-67 ELSE 8+h.n%20 END,@now)),
        CASE WHEN h.status=N'COMPLETED' THEN DATEADD(MINUTE,5,DATEADD(DAY,-(8+h.n%20),@now)) END,
        CASE WHEN h.status=N'COMPLETED' THEN DATEADD(MINUTE,125,DATEADD(DAY,-(8+h.n%20),@now)) END,
        DATEADD(MINUTE,CASE WHEN h.status=N'COMPLETED' THEN 90 ELSE 16 END,
            DATEADD(DAY,-CASE WHEN h.n>=68 THEN h.n-67 ELSE 8+h.n%20 END,@now))
    FROM @history h;
    UPDATE u SET balance=balance-h.amount FROM dbo.Users u JOIN
        (SELECT user_id,COUNT(*)*5000 amount FROM @history WHERE status=N'COMPLETED' GROUP BY user_id) h ON h.user_id=u.user_id;

    -- Live bookings use bank and slot codes, and obey one open booking per user/slot.
    DECLARE @live TABLE (username NVARCHAR(50),bank NVARCHAR(20),slot NVARCHAR(20),status NVARCHAR(20),age_min INT,due_min INT,extensions INT,cardless BIT);
    INSERT INTO @live VALUES
        (N'student2',N'DOMA-A',N'A01',N'ACTIVE',30,90,0,0),
        (N'student3',N'CANT-A',N'A01',N'ACTIVE',60,60,0,0),
        (N'student4',N'GYM-A',N'A01',N'ACTIVE',15,105,0,0),
        (N'student5',N'DOMA-B',N'B01',N'ACTIVE',180,-60,0,0),
        (N'student9',N'DOMA-A',N'A04',N'ACTIVE',170,-50,0,0),
        (N'student11',N'DOMA-A',N'A05',N'ACTIVE',90,75,3,0),
        (N'student12',N'DOMA-A',N'A06',N'ACTIVE',25,95,0,0),
        (N'student13',N'DOMA-A',N'A07',N'ACTIVE',20,100,0,0),
        (N'student14',N'DOMA-A',N'A08',N'ACTIVE',40,80,0,0),
        (N'student15',N'DOMA-A',N'A09',N'ACTIVE',35,85,0,0),
        (N'student16',N'DOMA-A',N'A10',N'RESERVED',2,180,0,1),
        (N'student17',N'DOMA-A',N'A11',N'RESERVED',5,180,0,0),
        (N'student18',N'CANT-A',N'A04',N'RESERVED',3,180,0,0),
        (N'student19',N'CANT-A',N'A05',N'ACTIVE',160,-40,0,0),
        (N'student20',N'GYM-A',N'A04',N'ACTIVE',10,110,0,0),
        (N'student21',N'GYM-A',N'A05',N'ACTIVE',30,90,0,0),
        (N'student22',N'GYM-B',N'B04',N'ACTIVE',20,100,0,0),
        (N'student23',N'GYM-B',N'B05',N'RESERVED',30,-15,0,0);
    DECLARE @newLive TABLE (user_id INT,paid_amount BIGINT);
    INSERT INTO dbo.Deposit (user_id,slot_id,plan_id,card_id,paid_amount,status,reserved_at,hold_until,started_at,due_at,extend_count)
    OUTPUT inserted.user_id,inserted.paid_amount INTO @newLive
    SELECT u.user_id,s.locker_slot_id,p.plan_id,CASE WHEN v.cardless=1 THEN NULL ELSE c.card_id END,
        p.price,v.status,DATEADD(MINUTE,-v.age_min,@now),
        CASE WHEN v.status=N'RESERVED' THEN DATEADD(MINUTE,v.due_min,@now) END,
        CASE WHEN v.status=N'ACTIVE' THEN DATEADD(MINUTE,-v.age_min,@now) END,
        CASE WHEN v.status=N'ACTIVE' THEN DATEADD(MINUTE,v.due_min,@now) END,v.extensions
    FROM @live v JOIN dbo.Users u ON u.username=v.username
    JOIN dbo.LockerBank b ON b.bank_code=v.bank JOIN dbo.LockerSlot s ON s.bank_id=b.bank_id AND s.slot_code=v.slot
    JOIN dbo.StoragePlan p ON p.plan_name=N'2 hours'
    OUTER APPLY (SELECT TOP 1 card_id FROM dbo.UserCard c WHERE c.user_id=u.user_id AND c.status=N'ACTIVE' ORDER BY card_id DESC) c
    WHERE u.balance>=p.price AND NOT EXISTS (SELECT 1 FROM dbo.Deposit d WHERE d.user_id=u.user_id AND d.status IN (N'ACTIVE',N'RESERVED'))
      AND NOT EXISTS (SELECT 1 FROM dbo.Deposit d WHERE d.slot_id=s.locker_slot_id AND d.status IN (N'ACTIVE',N'RESERVED'));
    UPDATE u SET balance=balance-x.paid_amount FROM dbo.Users u JOIN @newLive x ON x.user_id=u.user_id;
    UPDATE d SET card_id=c.card_id FROM dbo.Deposit d JOIN dbo.Users u ON u.user_id=d.user_id
    JOIN dbo.UserCard c ON c.user_id=u.user_id AND c.card_uid=N'04FF0012'
    WHERE u.username=N'student12' AND d.status IN (N'ACTIVE',N'RESERVED');
    UPDATE d SET extend_count=3 FROM dbo.Deposit d JOIN dbo.Users u ON u.user_id=d.user_id
    WHERE u.username=N'student11' AND d.status=N'ACTIVE';
    UPDATE s SET status=CASE d.status WHEN N'ACTIVE' THEN N'OCCUPIED' ELSE N'RESERVED' END
    FROM dbo.LockerSlot s JOIN dbo.Deposit d ON d.slot_id=s.locker_slot_id AND d.status IN (N'ACTIVE',N'RESERVED');

    -- 6. 350 dashboard sessions (50 per device), each with labels and 3 readings.
    DECLARE @sessions TABLE (session_id BIGINT PRIMARY KEY,label NVARCHAR(40));
    INSERT INTO dbo.LockerSession (device_id,device_seq,measured_at,ingested_at,door_open_sec,weight_delta_g,unlock_count,rfid_ok,stay_min,slot_id,card_uid,open_source)
    OUTPUT inserted.session_id,N'NORMAL' INTO @sessions
    SELECT d.device_id,2000+n.n,DATEADD(MINUTE,-(51-n.n)*3,@now),DATEADD(SECOND,3,DATEADD(MINUTE,-(51-n.n)*3,@now)),
        3+n.n%7,-(10+n.n%80),1,1,15+n.n%70,s.locker_slot_id,c.card_uid,N'RFID'
    FROM @devices v JOIN dbo.Device d ON d.device_code=v.code JOIN dbo.LockerBank b ON b.bank_code=v.bank
    CROSS JOIN @numbers n
    CROSS APPLY (SELECT TOP 1 locker_slot_id FROM dbo.LockerSlot WHERE bank_id=b.bank_id ORDER BY slot_code) s
    OUTER APPLY (SELECT TOP 1 user_id FROM dbo.Deposit WHERE slot_id=s.locker_slot_id AND status=N'ACTIVE') owner
    OUTER APPLY (SELECT TOP 1 c.card_uid FROM dbo.UserCard c JOIN dbo.Users u ON u.user_id=c.user_id
        WHERE c.user_id=COALESCE(owner.user_id,(SELECT user_id FROM dbo.Users WHERE username=N'student1'))
          AND c.status=N'ACTIVE' ORDER BY c.card_id DESC) c
    WHERE n.n<=50 AND NOT EXISTS (SELECT 1 FROM dbo.LockerSession ls WHERE ls.device_id=d.device_id AND ls.device_seq=2000+n.n);

    -- Explicit exceptional sessions have matching alert evidence below.
    DECLARE @cases TABLE (n INT,bank NVARCHAR(20),slot NVARCHAR(20),label NVARCHAR(40),door FLOAT,weight FLOAT,unlocks INT,rfid BIT,stay FLOAT,card NVARCHAR(32),source NVARCHAR(10),reason NVARCHAR(200));
    INSERT INTO @cases VALUES
        (1,N'LIB-B',N'B01',N'FORCED_OPEN',24,0,4,0,20,NULL,N'RFID',N'Cửa mở khi RFID không hợp lệ'),
        (2,N'CANT-A',N'A06',N'SUSPECTED_SPOOF',0,120,1,1,20,N'04DE0025',N'RFID',N'Khối lượng thay đổi trong khi cửa báo đóng'),
        (3,N'DOMA-A',N'A09',N'ITEM_LEFT',7,220,1,1,20,N'04DE0015',N'RFID',N'Còn vật nặng 220g sau khi lấy đồ'),
        (4,N'DOMA-A',N'A04',N'OVERDUE',5,0,1,1,170,N'04DE0009',N'RFID',N'Gửi đồ 170 phút, vượt gói 120 phút và thời gian ân hạn'),
        (5,N'DOMA-A',N'A08',N'WRONG_USER',5,0,1,1,20,N'04DE0025',N'RFID',N'Thẻ student25 truy cập slot của student14'),
        (6,N'DOMA-A',N'A06',N'LOST_CARD_USED',5,0,1,1,20,N'04DE0012',N'RFID',N'Thẻ đã báo mất được sử dụng lại'),
        (7,N'DOMA-A',N'A07',N'LOST_CARD_USED',5,0,1,1,20,N'04DE0013',N'RFID',N'Thẻ bị khóa được sử dụng lại'),
        (8,N'DOMA-B',N'B04',N'SENSOR_FAULT',5,0,1,1,20,N'04DE0024',N'RFID',N'Hiệu chuẩn cảm biến khối lượng hết hạn'),
        (9,N'LIB-B',N'B04',N'SUSPECTED_SPOOF',6,0,1,1,20,NULL,N'REMOTE',N'Mở từ xa không có lệnh hợp lệ'),
        (10,N'LIB-B',N'B05',N'SENSOR_FAULT',5,0,1,1,20,N'04DE0026',N'RFID',N'Đồng hồ thiết bị chạy nhanh hơn máy chủ 15 phút'),
        (11,N'LIB-B',N'B06',N'SENSOR_FAULT',5,25000,1,1,20,N'04DE0027',N'RFID',N'Khối lượng 25000g vượt giới hạn cảm biến'),
        (12,N'GYM-A',N'A06',N'ML_ANOMALY',18,0,3,1,100,N'04DE0028',N'RFID',N'Điểm bất thường ML mô phỏng là 0.94');
    INSERT INTO dbo.LockerSession (device_id,device_seq,measured_at,ingested_at,door_open_sec,weight_delta_g,unlock_count,rfid_ok,stay_min,slot_id,card_uid,open_source,command_id)
    OUTPUT inserted.session_id,N'CASE' INTO @sessions
    SELECT b.device_id,9000+c.n,CASE WHEN c.n=10 THEN DATEADD(MINUTE,15,@now) ELSE DATEADD(MINUTE,-c.n,@now) END,
        @now,c.door,c.weight,c.unlocks,c.rfid,c.stay,s.locker_slot_id,c.card,c.source,
        CASE WHEN c.n=9 THEN 999999 END
    FROM @cases c JOIN dbo.LockerBank b ON b.bank_code=c.bank JOIN dbo.LockerSlot s ON s.bank_id=b.bank_id AND s.slot_code=c.slot
    WHERE NOT EXISTS (SELECT 1 FROM dbo.LockerSession ls WHERE ls.device_id=b.device_id AND ls.device_seq=9000+c.n);
    UPDATE x SET label=c.label FROM @sessions x JOIN dbo.LockerSession s ON s.session_id=x.session_id
    JOIN @cases c ON s.device_seq=9000+c.n AND s.slot_id=(SELECT ls.locker_slot_id FROM dbo.LockerSlot ls JOIN dbo.LockerBank b ON b.bank_id=ls.bank_id WHERE b.bank_code=c.bank AND ls.slot_code=c.slot);
    -- Normal-looking samples on device 4 are sensor faults due to expired calibration.
    UPDATE x SET label=N'SENSOR_FAULT' FROM @sessions x JOIN dbo.LockerSession s ON s.session_id=x.session_id
    JOIN dbo.Device d ON d.device_id=s.device_id WHERE d.device_code=N'LOCKER-04' AND x.label=N'NORMAL';
    INSERT INTO dbo.LockerSessionLabel (session_id,label,labeled_by,labeled_at)
    SELECT x.session_id,x.label,@admin,@now FROM @sessions x
    WHERE NOT EXISTS (SELECT 1 FROM dbo.LockerSessionLabel l WHERE l.session_id=x.session_id);
    INSERT INTO dbo.LockerSessionReading (session_id,sensor_type_id,measured_at,value)
    SELECT x.session_id,t.sensor_type_id,s.measured_at,CASE t.name WHEN N'DOOR' THEN s.door_open_sec WHEN N'WEIGHT' THEN s.weight_delta_g ELSE s.stay_min END
    FROM @sessions x JOIN dbo.LockerSession s ON s.session_id=x.session_id CROSS JOIN dbo.SensorType t
    WHERE t.name IN (N'DOOR',N'WEIGHT',N'STAY');

    -- 7. Alerts with evidence, offline device, and linked maintenance tickets.
    DECLARE @alerts TABLE (alert_id INT,session_id BIGINT,label NVARCHAR(40));
    INSERT INTO dbo.Alert (device_id,session_id,source,label,risk_score,status,created_at)
    OUTPUT inserted.alert_id,inserted.session_id,inserted.label INTO @alerts
    SELECT s.device_id,s.session_id,CASE c.label WHEN N'ML_ANOMALY' THEN N'ML' ELSE N'RULE' END,
        c.label,CASE WHEN c.label=N'ML_ANOMALY' THEN 0.94 ELSE 0.85 END,
        CASE WHEN c.label=N'OVERDUE' THEN N'RESOLVED' ELSE N'OPEN' END,DATEADD(MINUTE,-c.n,@now)
    FROM @cases c JOIN dbo.LockerBank b ON b.bank_code=c.bank
    JOIN dbo.LockerSession s ON s.device_id=b.device_id AND s.device_seq=9000+c.n
    WHERE NOT EXISTS (SELECT 1 FROM dbo.Alert a WHERE a.session_id=s.session_id AND a.label=c.label);
    INSERT INTO dbo.AlertEvidence (alert_id,item,value_text)
    SELECT a.alert_id,N'demo_case',c.reason FROM @alerts a JOIN dbo.LockerSession s ON s.session_id=a.session_id JOIN @cases c ON s.device_seq=9000+c.n;
    INSERT INTO dbo.AlertEvidence (alert_id,item,value_text)
    SELECT a.alert_id,v.item,v.value FROM @alerts a JOIN dbo.LockerSession s ON s.session_id=a.session_id
    CROSS APPLY (VALUES (N'door_open_sec',CONVERT(NVARCHAR(200),s.door_open_sec)),
        (N'weight_delta_g',CONVERT(NVARCHAR(200),s.weight_delta_g)),(N'card_uid',ISNULL(s.card_uid,N'none')),
        (N'open_source',s.open_source)) v(item,value);
    INSERT INTO dbo.Alert (device_id,session_id,source,label,risk_score,status,created_at)
    OUTPUT inserted.alert_id,inserted.session_id,inserted.label INTO @alerts
    SELECT d.device_id,NULL,N'RULE',N'DEVICE_OFFLINE',NULL,N'OPEN',DATEADD(HOUR,-2,@now)
    FROM dbo.Device d WHERE d.device_code=N'LOCKER-07'
      AND NOT EXISTS (SELECT 1 FROM dbo.Alert a WHERE a.device_id=d.device_id AND a.label=N'DEVICE_OFFLINE' AND a.status=N'OPEN');
    INSERT INTO dbo.AlertEvidence (alert_id,item,value_text)
    SELECT a.alert_id,N'last_seen_utc',CONVERT(NVARCHAR(200),d.last_seen,126)
    FROM @alerts x JOIN dbo.Alert a ON a.alert_id=x.alert_id JOIN dbo.Device d ON d.device_id=a.device_id WHERE a.label=N'DEVICE_OFFLINE';
    -- Resolved historical sensor alerts also keep untrustworthy samples out of
    -- v_LockerSession_Features, which excludes sessions linked to sensor faults.
    INSERT INTO dbo.Alert (device_id,session_id,source,label,status,created_at)
    OUTPUT inserted.alert_id,inserted.session_id,inserted.label INTO @alerts
    SELECT s.device_id,s.session_id,N'RULE',N'SENSOR_FAULT',N'RESOLVED',s.ingested_at
    FROM @sessions x JOIN dbo.LockerSession s ON s.session_id=x.session_id
    WHERE x.label=N'SENSOR_FAULT' AND s.device_seq BETWEEN 2001 AND 2050
      AND NOT EXISTS (SELECT 1 FROM dbo.Alert a WHERE a.session_id=s.session_id AND a.label=N'SENSOR_FAULT');
    INSERT INTO dbo.AlertEvidence (alert_id,item,value_text)
    SELECT x.alert_id,N'reason',N'Phiên mô phỏng lịch sử: hiệu chuẩn đã hết hạn'
    FROM @alerts x JOIN dbo.LockerSession s ON s.session_id=x.session_id
    WHERE x.label=N'SENSOR_FAULT' AND s.device_seq BETWEEN 2001 AND 2050;
    INSERT INTO dbo.MaintenanceTicket (alert_id,device_id,assigned_to,note,status,opened_at,closed_at)
    SELECT a.alert_id,a.device_id,CASE WHEN c.n%2=0 THEN @tech1 ELSE @tech2 END,
        N'DEMO_V2: '+c.reason,N'OPEN',a.created_at,NULL
    FROM @alerts x JOIN dbo.Alert a ON a.alert_id=x.alert_id JOIN dbo.LockerSession s ON s.session_id=a.session_id
    JOIN @cases c ON s.device_seq=9000+c.n WHERE a.label=N'SENSOR_FAULT';
    UPDATE ls SET status=N'MAINTENANCE' FROM dbo.LockerSlot ls
    JOIN dbo.LockerSession s ON s.slot_id=ls.locker_slot_id JOIN @alerts x ON x.session_id=s.session_id AND x.label=N'SENSOR_FAULT'
    JOIN dbo.Alert a ON a.alert_id=x.alert_id AND a.status=N'OPEN';
    INSERT INTO dbo.MaintenanceTicket (device_id,assigned_to,note,status,opened_at,closed_at)
    SELECT d.device_id,CASE WHEN n.n%2=0 THEN @tech1 ELSE @tech2 END,
        N'DEMO_V2: Kiểm tra chốt cửa và vệ sinh cảm biến lần '+CONVERT(NVARCHAR(2),n.n),
        N'CLOSED',DATEADD(DAY,-(n.n+2),@now),DATEADD(HOUR,2,DATEADD(DAY,-(n.n+2),@now))
    FROM @numbers n JOIN @devices v ON v.n=1+n.n%7 JOIN dbo.Device d ON d.device_code=v.code WHERE n.n<=9;

    -- 8. Remote commands in all four states, including a completed command/session link.
    INSERT INTO dbo.RemoteCommand (device_id,slot_id,action,reason,requested_by,status,created_at,expires_at,sent_at,done_at)
    SELECT b.device_id,s.locker_slot_id,N'UNLOCK',N'DEMO_V2: hỗ trợ mở tủ lần '+CONVERT(NVARCHAR(2),n.n),@operator,
        CASE n.n%4 WHEN 0 THEN N'PENDING' WHEN 1 THEN N'SENT' WHEN 2 THEN N'DONE' ELSE N'EXPIRED' END,
        DATEADD(MINUTE,-(n.n+5),@now),CASE WHEN n.n%4 IN (0,1) THEN DATEADD(MINUTE,60,@now) ELSE DATEADD(MINUTE,-n.n,@now) END,
        CASE WHEN n.n%4 IN (1,2) THEN DATEADD(MINUTE,-(n.n+4),@now) END,
        CASE WHEN n.n%4=2 THEN DATEADD(MINUTE,-n.n,@now) END
    FROM @numbers n JOIN dbo.LockerBank b ON b.bank_code=N'GYM-A'
    JOIN dbo.LockerSlot s ON s.bank_id=b.bank_id AND s.slot_code=N'A'+RIGHT(N'0'+CONVERT(NVARCHAR(2),4+n.n%10),2)
    WHERE n.n<=12 AND NOT EXISTS (SELECT 1 FROM dbo.RemoteCommand c WHERE c.reason=N'DEMO_V2: hỗ trợ mở tủ lần '+CONVERT(NVARCHAR(2),n.n));
    DECLARE @command BIGINT=(SELECT TOP 1 command_id FROM dbo.RemoteCommand WHERE reason=N'DEMO_V2: hỗ trợ mở tủ lần 2' AND status=N'DONE');
    IF @command IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.LockerSession WHERE command_id=@command)
    BEGIN
        INSERT INTO dbo.LockerSession (device_id,device_seq,measured_at,ingested_at,door_open_sec,weight_delta_g,unlock_count,rfid_ok,stay_min,slot_id,open_source,command_id)
        SELECT device_id,9501,done_at,done_at,4,0,1,1,1,slot_id,N'REMOTE',command_id FROM dbo.RemoteCommand WHERE command_id=@command;
        DECLARE @remoteSession BIGINT=SCOPE_IDENTITY();
        UPDATE dbo.RemoteCommand SET session_id=@remoteSession WHERE command_id=@command;
        INSERT INTO dbo.LockerSessionLabel (session_id,label,labeled_by) VALUES (@remoteSession,N'NORMAL',@admin);
        INSERT INTO dbo.LockerSessionReading (session_id,sensor_type_id,measured_at,value)
        SELECT s.session_id,t.sensor_type_id,s.measured_at,CASE t.name WHEN N'DOOR' THEN s.door_open_sec WHEN N'WEIGHT' THEN s.weight_delta_g ELSE s.stay_min END
        FROM dbo.LockerSession s CROSS JOIN dbo.SensorType t
        WHERE s.session_id=@remoteSession AND t.name IN (N'DOOR',N'WEIGHT',N'STAY');
    END;

    -- 9. Bring synthetic training examples to 480 rows, with all six model labels.
    -- Preserve imported research sessions and keep simulated data out of that dataset.
    IF OBJECT_ID(N'dbo.RawGarageDoor',N'U') IS NULL
    BEGIN
        DECLARE @publicCount INT=(SELECT COUNT(*) FROM dbo.PublicSession);
        INSERT INTO dbo.PublicSession (door_open_sec,weight_delta_g,unlock_count,rfid_ok,stay_min,label,sent)
        SELECT CASE n%6 WHEN 1 THEN 25+n%9 WHEN 5 THEN 0 ELSE 3+n%7 END,
            CASE n%6 WHEN 4 THEN 150+n%300 WHEN 5 THEN 100+n%200 ELSE -10-n%80 END,
            CASE n%6 WHEN 1 THEN 4 ELSE 1 END,CASE n%6 WHEN 1 THEN 0 ELSE 1 END,
            CASE n%6 WHEN 3 THEN 180+n%90 ELSE 10+n%90 END,
            CASE n%6 WHEN 0 THEN N'NORMAL' WHEN 1 THEN N'FORCED_OPEN' WHEN 2 THEN N'WRONG_USER'
                WHEN 3 THEN N'OVERDUE' WHEN 4 THEN N'ITEM_LEFT' ELSE N'SUSPECTED_SPOOF' END,0
        FROM @numbers WHERE n<=480-@publicCount;
    END;

    -- 10. Narrow status permission for admins and technicians.
    IF NOT EXISTS (SELECT 1 FROM dbo.Permissions WHERE resource=N'SLOTSTATUS' AND action=N'WRITE')
        INSERT INTO dbo.Permissions (resource,action) VALUES (N'SLOTSTATUS',N'WRITE');
    INSERT INTO dbo.RolePerm (role_id,perm_id)
    SELECT r.role_id,p.perm_id FROM dbo.Roles r CROSS JOIN dbo.Permissions p
    WHERE r.role_name IN (N'ADMIN',N'TECHNICIAN') AND p.resource=N'SLOTSTATUS' AND p.action=N'WRITE'
      AND NOT EXISTS (SELECT 1 FROM dbo.RolePerm rp WHERE rp.role_id=r.role_id AND rp.perm_id=p.perm_id);

    -- Seed audit activity through the real hash-chain procedure.
    DECLARE @auditObjects TABLE (n INT IDENTITY,kind NVARCHAR(50),id BIGINT,detail NVARCHAR(200));
    INSERT INTO @auditObjects SELECT N'ALERT',alert_id,N'Demo alert: '+label FROM @alerts;
    INSERT INTO @auditObjects SELECT N'MAINTENANCE',ticket_id,note FROM dbo.MaintenanceTicket WHERE note LIKE N'DEMO_V2:%';
    INSERT INTO @auditObjects SELECT N'COMMAND',command_id,reason FROM dbo.RemoteCommand WHERE reason LIKE N'DEMO_V2:%';
    INSERT INTO @auditObjects SELECT N'TOPUP',request_id,transfer_code+N': '+status FROM dbo.TopupRequest WHERE transfer_code LIKE N'DEMO-V2-TOPUP-%';
    DECLARE @i INT=1,@kind NVARCHAR(50),@object BIGINT,@detail NVARCHAR(200);
    WHILE @i<=(SELECT COUNT(*) FROM @auditObjects)
    BEGIN
        SELECT @kind=kind,@object=id,@detail=detail FROM @auditObjects WHERE n=@i;
        EXEC dbo.Audit_Append @admin,N'DEMO_HISTORY',@kind,@object,@detail;
        SET @i=@i+1;
    END;
    EXEC dbo.Audit_Append @admin,N'SEED',N'DATABASE',0,N'DEMO_DATA_V2';
    COMMIT;
    PRINT 'Demo users, booking history, wallet activity, telemetry and special cases loaded.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT>0 ROLLBACK;
    THROW;
END CATCH;
GO
