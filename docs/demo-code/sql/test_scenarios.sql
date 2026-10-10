USE PRJ301_LOCKER;
GO
SET NOCOUNT ON;
SET QUOTED_IDENTIFIER ON;
GO
CREATE PROCEDURE #chk @name NVARCHAR(80), @ok BIT, @detail NVARCHAR(300) = N''
AS PRINT CASE WHEN @ok = 1 THEN 'PASS ' ELSE 'FAIL ' END + @name + CASE WHEN @ok = 1 THEN N'' ELSE N'  -> ' + @detail END;
GO
DECLARE @op INT = (SELECT user_id FROM Users WHERE username = N'operator1');
DECLARE @s1 INT = (SELECT user_id FROM Users WHERE username = N'student1');
DECLARE @s2 INT = (SELECT user_id FROM Users WHERE username = N'student2');
DECLARE @s3 INT = (SELECT user_id FROM Users WHERE username = N'student3');
DECLARE @a01 INT = (SELECT s.locker_slot_id FROM LockerSlot s JOIN LockerBank b ON b.bank_id = s.bank_id WHERE b.bank_code = N'LIB-A' AND s.slot_code = N'A01');
DECLARE @x INT, @n INT, @st NVARCHAR(30), @cmd BIGINT, @dep BIGINT, @ok BIT, @dt NVARCHAR(300);

PRINT '=== Case 1: locker goes offline';
EXEC Device_Heartbeat 1;
SELECT @st = status FROM Device WHERE device_id = 1;
SET @ok = 1; SET @dt = CAST(@st AS NVARCHAR(300)); EXEC #chk 'heartbeat keeps device ACTIVE', @ok, @dt;
UPDATE Device SET last_seen = DATEADD(MINUTE, -5, SYSUTCDATETIME()) WHERE device_id = 1;
EXEC Device_MarkOffline;
EXEC Device_MarkOffline;                                   -- second run must not add a second alert
SELECT @st = status FROM Device WHERE device_id = 1;
SELECT @n = COUNT(*) FROM Alert WHERE label = N'DEVICE_OFFLINE' AND status = N'OPEN';
SET @ok = CASE WHEN (@st = N'OFFLINE') THEN 1 ELSE 0 END; SET @dt = CAST(@st AS NVARCHAR(300)); EXEC #chk 'device turns OFFLINE', @ok, @dt;
SET @ok = CASE WHEN (@n = 1) THEN 1 ELSE 0 END; SET @dt = CAST(@n AS NVARCHAR(300)); EXEC #chk 'exactly one OPEN DEVICE_OFFLINE alert', @ok, @dt;
SELECT @n = COUNT(*) FROM AlertEvidence e JOIN Alert a ON a.alert_id = e.alert_id WHERE a.label = N'DEVICE_OFFLINE';
SET @ok = CASE WHEN (@n = 1) THEN 1 ELSE 0 END; SET @dt = CAST(@n AS NVARCHAR(300)); EXEC #chk 'alert has evidence', @ok, @dt;
SELECT @n = COUNT(*) FROM v_LockerSlotMap WHERE bank_code = N'LIB-A' AND display_status = N'OFFLINE';
SET @ok = CASE WHEN (@n = 4) THEN 1 ELSE 0 END; SET @dt = CAST(@n AS NVARCHAR(300)); EXEC #chk 'map shows 4 OFFLINE doors', @ok, @dt;
BEGIN TRY EXEC Deposit_Reserve @s2, @a01, 1, @dep OUTPUT; SET @ok = 0; SET @dt = CAST('no error' AS NVARCHAR(300)); EXEC #chk 'booking refused while offline', @ok, @dt;
END TRY BEGIN CATCH SET @ok = CASE WHEN ERROR_NUMBER() = 50035 THEN 1 ELSE 0 END; SET @dt = CAST(ERROR_MESSAGE() AS NVARCHAR(300)); EXEC #chk 'booking refused while offline', @ok, @dt; END CATCH
BEGIN TRY EXEC RemoteCommand_Create @a01, N'Student forgot card', @op, @cmd OUTPUT; SET @ok = 0; SET @dt = CAST('no error' AS NVARCHAR(300)); EXEC #chk 'remote unlock refused while offline', @ok, @dt;
END TRY BEGIN CATCH SET @ok = CASE WHEN ERROR_NUMBER() = 50011 THEN 1 ELSE 0 END; SET @dt = CAST(ERROR_MESSAGE() AS NVARCHAR(300)); EXEC #chk 'remote unlock refused while offline', @ok, @dt; END CATCH
EXEC Device_Heartbeat 1;
SELECT @st = status FROM Device WHERE device_id = 1;
SELECT @n = COUNT(*) FROM Alert WHERE label = N'DEVICE_OFFLINE' AND status = N'OPEN';
SET @ok = CASE WHEN (@st = N'ACTIVE') THEN 1 ELSE 0 END; SET @dt = CAST(@st AS NVARCHAR(300)); EXEC #chk 'heartbeat brings it back ACTIVE', @ok, @dt;
SET @ok = CASE WHEN (@n = 0) THEN 1 ELSE 0 END; SET @dt = CAST(@n AS NVARCHAR(300)); EXEC #chk 'alert closed on reconnect', @ok, @dt;

PRINT '=== Case 2: remote unlock';
BEGIN TRY EXEC RemoteCommand_Create @a01, N'ab', @op, @cmd OUTPUT; SET @ok = 0; SET @dt = CAST('no error' AS NVARCHAR(300)); EXEC #chk 'short reason refused', @ok, @dt;
END TRY BEGIN CATCH SET @ok = CASE WHEN ERROR_NUMBER() = 50013 THEN 1 ELSE 0 END; SET @dt = CAST(ERROR_MESSAGE() AS NVARCHAR(300)); EXEC #chk 'short reason refused', @ok, @dt; END CATCH
EXEC RemoteCommand_Create @a01, N'Student forgot card, ID checked', @op, @cmd OUTPUT;
SET @ok = CASE WHEN (@cmd > 0) THEN 1 ELSE 0 END; SET @dt = CAST(@cmd AS NVARCHAR(300)); EXEC #chk 'command created', @ok, @dt;
CREATE TABLE #t (command_id BIGINT, slot_code NVARCHAR(20), action NVARCHAR(20));
INSERT INTO #t EXEC RemoteCommand_TakePending 1;
SELECT @n = COUNT(*) FROM #t WHERE command_id = @cmd AND slot_code = N'A01' AND action = N'UNLOCK';
SET @ok = CASE WHEN (@n = 1) THEN 1 ELSE 0 END; SET @dt = CAST(@n AS NVARCHAR(300)); EXEC #chk 'TakePending returns it once', @ok, @dt;
DELETE FROM #t; INSERT INTO #t EXEC RemoteCommand_TakePending 1;
SELECT @n = COUNT(*) FROM #t;
SET @ok = CASE WHEN (@n = 0) THEN 1 ELSE 0 END; SET @dt = CAST(@n AS NVARCHAR(300)); EXEC #chk 'second TakePending is empty', @ok, @dt;
SELECT @st = status FROM RemoteCommand WHERE command_id = @cmd;
SET @ok = CASE WHEN (@st = N'SENT') THEN 1 ELSE 0 END; SET @dt = CAST(@st AS NVARCHAR(300)); EXEC #chk 'command status SENT', @ok, @dt;
EXEC RemoteCommand_Create @a01, N'Second command to expire', @op, @cmd OUTPUT;
UPDATE RemoteCommand SET expires_at = DATEADD(MINUTE, -1, SYSUTCDATETIME()) WHERE command_id = @cmd;
EXEC RemoteCommand_Expire;
SELECT @st = status FROM RemoteCommand WHERE command_id = @cmd;
SET @ok = CASE WHEN (@st = N'EXPIRED') THEN 1 ELSE 0 END; SET @dt = CAST(@st AS NVARCHAR(300)); EXEC #chk 'old PENDING command expires', @ok, @dt;
SELECT @n = COUNT(*) FROM RemoteCommand WHERE status = N'SENT';
SET @ok = CASE WHEN (@n = 1) THEN 1 ELSE 0 END; SET @dt = CAST(@n AS NVARCHAR(300)); EXEC #chk 'SENT command is not expired', @ok, @dt;

PRINT '=== Case 3: lost card';
DECLARE @c1 INT = (SELECT card_id FROM UserCard WHERE user_id = @s1);
DECLARE @newc INT;
BEGIN TRY EXEC UserCard_ReportLost @c1, @s2; SET @ok = 0; SET @dt = CAST('no error' AS NVARCHAR(300)); EXEC #chk 'cannot report another user card', @ok, @dt;
END TRY BEGIN CATCH SET @ok = CASE WHEN ERROR_NUMBER() = 50020 THEN 1 ELSE 0 END; SET @dt = CAST(ERROR_MESSAGE() AS NVARCHAR(300)); EXEC #chk 'cannot report another user card', @ok, @dt; END CATCH
EXEC UserCard_ReportLost @c1, @s1;
SELECT @st = status FROM UserCard WHERE card_id = @c1;
SET @ok = CASE WHEN (@st = N'LOST') THEN 1 ELSE 0 END; SET @dt = CAST(@st AS NVARCHAR(300)); EXEC #chk 'owner reports it lost', @ok, @dt;
BEGIN TRY EXEC UserCard_ReportLost @c1, @s1; SET @ok = 0; SET @dt = CAST('no error' AS NVARCHAR(300)); EXEC #chk 'second report refused', @ok, @dt;
END TRY BEGIN CATCH SET @ok = CASE WHEN ERROR_NUMBER() = 50020 THEN 1 ELSE 0 END; SET @dt = CAST(ERROR_MESSAGE() AS NVARCHAR(300)); EXEC #chk 'second report refused', @ok, @dt; END CATCH
SELECT @n = COUNT(*) FROM UserCard WHERE status <> N'ACTIVE';
SET @ok = CASE WHEN (@n = 1) THEN 1 ELSE 0 END; SET @dt = CAST(@n AS NVARCHAR(300)); EXEC #chk 'blockedUids query sees 1 card', @ok, @dt;
EXEC UserCard_Replace @c1, N'04ABCDEF', @op, @newc OUTPUT;
SELECT @n = COUNT(*) FROM Deposit WHERE card_id = @newc AND status = N'ACTIVE';
SET @ok = CASE WHEN (@n = 1) THEN 1 ELSE 0 END; SET @dt = CAST(@n AS NVARCHAR(300)); EXEC #chk 'active booking follows the new card', @ok, @dt;
BEGIN TRY EXEC UserCard_Replace @newc, N'04FFFFFF', @op, @newc OUTPUT; SET @ok = 0; SET @dt = CAST('no error' AS NVARCHAR(300)); EXEC #chk 'active card cannot be replaced', @ok, @dt;
END TRY BEGIN CATCH SET @ok = CASE WHEN ERROR_NUMBER() = 50021 THEN 1 ELSE 0 END; SET @dt = CAST(ERROR_MESSAGE() AS NVARCHAR(300)); EXEC #chk 'active card cannot be replaced', @ok, @dt; END CATCH

PRINT '=== Case 4: booking and no-show';
EXEC Deposit_Reserve @s2, @a01, 1, @dep OUTPUT;
SELECT @st = status FROM LockerSlot WHERE locker_slot_id = @a01;
SET @ok = CASE WHEN (@st = N'RESERVED') THEN 1 ELSE 0 END; SET @dt = CAST(@st AS NVARCHAR(300)); EXEC #chk 'reserve sets slot RESERVED', @ok, @dt;
BEGIN TRY EXEC Deposit_Reserve @s2, @a01, 1, @dep OUTPUT; SET @ok = 0; SET @dt = CAST('no error' AS NVARCHAR(300)); EXEC #chk 'one open booking per user', @ok, @dt;
END TRY BEGIN CATCH SET @ok = CASE WHEN ERROR_NUMBER() = 50032 THEN 1 ELSE 0 END; SET @dt = CAST(ERROR_MESSAGE() AS NVARCHAR(300)); EXEC #chk 'one open booking per user', @ok, @dt; END CATCH
DECLARE @s3card INT = (SELECT card_id FROM UserCard WHERE user_id = @s3);
BEGIN TRY EXEC Deposit_Reserve @s3, @a01, 1, @dep OUTPUT; SET @ok = 0; SET @dt = CAST('no error' AS NVARCHAR(300)); EXEC #chk 'second user cannot take the same slot', @ok, @dt;
END TRY BEGIN CATCH SET @ok = CASE WHEN ERROR_NUMBER() = 50033 THEN 1 ELSE 0 END; SET @dt = CAST(ERROR_MESSAGE() AS NVARCHAR(300)); EXEC #chk 'second user cannot take the same slot', @ok, @dt; END CATCH
SELECT @dep = deposit_id FROM Deposit WHERE user_id = @s2 AND status = N'RESERVED';
BEGIN TRY EXEC Deposit_Cancel @dep, @s3; SET @ok = 0; SET @dt = CAST('no error' AS NVARCHAR(300)); EXEC #chk 'only the owner cancels', @ok, @dt;
END TRY BEGIN CATCH SET @ok = CASE WHEN ERROR_NUMBER() = 50036 THEN 1 ELSE 0 END; SET @dt = CAST(ERROR_MESSAGE() AS NVARCHAR(300)); EXEC #chk 'only the owner cancels', @ok, @dt; END CATCH
UPDATE Deposit SET hold_until = DATEADD(MINUTE, -1, SYSUTCDATETIME()) WHERE deposit_id = @dep;
EXEC Deposit_ExpireNoShow;
SELECT @st = status FROM Deposit WHERE deposit_id = @dep;
SET @ok = CASE WHEN (@st = N'NO_SHOW') THEN 1 ELSE 0 END; SET @dt = CAST(@st AS NVARCHAR(300)); EXEC #chk 'expired reservation is NO_SHOW', @ok, @dt;
SELECT @st = status FROM LockerSlot WHERE locker_slot_id = @a01;
SET @ok = CASE WHEN (@st = N'AVAILABLE') THEN 1 ELSE 0 END; SET @dt = CAST(@st AS NVARCHAR(300)); EXEC #chk 'slot is AVAILABLE again', @ok, @dt;
-- two more no-shows, then the fourth reservation is refused
DECLARE @k INT = 0;
WHILE @k < 2
BEGIN
    EXEC Deposit_Reserve @s2, @a01, 1, @dep OUTPUT;
    UPDATE Deposit SET hold_until = DATEADD(MINUTE, -1, SYSUTCDATETIME()) WHERE deposit_id = @dep;
    EXEC Deposit_ExpireNoShow;
    SET @k += 1;
END
BEGIN TRY EXEC Deposit_Reserve @s2, @a01, 1, @dep OUTPUT; SET @ok = 0; SET @dt = CAST('no error' AS NVARCHAR(300)); EXEC #chk '3 no-shows block booking', @ok, @dt;
END TRY BEGIN CATCH SET @ok = CASE WHEN ERROR_NUMBER() = 50031 THEN 1 ELSE 0 END; SET @dt = CAST(ERROR_MESSAGE() AS NVARCHAR(300)); EXEC #chk '3 no-shows block booking', @ok, @dt; END CATCH
-- cancel path
EXEC Deposit_Reserve @s3, @a01, 1, @dep OUTPUT;
EXEC Deposit_Cancel @dep, @s3;
SELECT @st = status FROM Deposit WHERE deposit_id = @dep;
SET @ok = CASE WHEN (@st = N'CANCELLED') THEN 1 ELSE 0 END; SET @dt = CAST(@st AS NVARCHAR(300)); EXEC #chk 'owner cancels a reservation', @ok, @dt;
-- extend path on student1 active booking
DECLARE @d1 BIGINT = (SELECT deposit_id FROM Deposit WHERE user_id = @s1 AND status = N'ACTIVE');
DECLARE @due1 DATETIME2 = (SELECT due_at FROM Deposit WHERE deposit_id = @d1);
EXEC Deposit_Extend @d1, 60, @s1;
SELECT @n = DATEDIFF(MINUTE, @due1, due_at) FROM Deposit WHERE deposit_id = @d1;
SET @ok = CASE WHEN (@n = 60) THEN 1 ELSE 0 END; SET @dt = CAST(@n AS NVARCHAR(300)); EXEC #chk 'extend adds 60 minutes', @ok, @dt;
EXEC Deposit_Extend @d1, 30, @s1; EXEC Deposit_Extend @d1, 30, @s1;
BEGIN TRY EXEC Deposit_Extend @d1, 30, @s1; SET @ok = 0; SET @dt = CAST('no error' AS NVARCHAR(300)); EXEC #chk '4th extension refused', @ok, @dt;
END TRY BEGIN CATCH SET @ok = CASE WHEN ERROR_NUMBER() = 50039 THEN 1 ELSE 0 END; SET @dt = CAST(ERROR_MESSAGE() AS NVARCHAR(300)); EXEC #chk '4th extension refused', @ok, @dt; END CATCH
-- check-in of student7 reservation on A03, complete of student1 on A02
EXEC Deposit_CheckIn 1, N'A03';
SELECT @st = status FROM Deposit WHERE user_id = (SELECT user_id FROM Users WHERE username = N'student7') AND status IN (N'ACTIVE', N'RESERVED');
SET @ok = CASE WHEN (@st = N'ACTIVE') THEN 1 ELSE 0 END; SET @dt = CAST(@st AS NVARCHAR(300)); EXEC #chk 'check-in starts the clock', @ok, @dt;
SELECT @n = COUNT(*) FROM Deposit WHERE user_id = (SELECT user_id FROM Users WHERE username = N'student7') AND due_at IS NOT NULL;
SET @ok = CASE WHEN (@n = 1) THEN 1 ELSE 0 END; SET @dt = CAST(@n AS NVARCHAR(300)); EXEC #chk 'check-in sets due_at', @ok, @dt;
EXEC Deposit_Complete 1, N'A02';
SELECT @st = status FROM Deposit WHERE deposit_id = @d1;
SET @ok = CASE WHEN (@st = N'COMPLETED') THEN 1 ELSE 0 END; SET @dt = CAST(@st AS NVARCHAR(300)); EXEC #chk 'session end completes the booking', @ok, @dt;

PRINT '=== Case 5: broken sensor';
DECLARE @sess BIGINT, @alert INT, @tick INT;
INSERT INTO LockerSession (device_id, device_seq, measured_at, door_open_sec, weight_delta_g, unlock_count, rfid_ok, stay_min, slot_id, card_uid, open_source)
VALUES (1, 9001, SYSUTCDATETIME(), 6, -5000, 2, 0, 30, @a01, N'0499AABB', N'RFID');
SET @sess = SCOPE_IDENTITY();
INSERT INTO Alert (device_id, session_id, source, label) VALUES (1, @sess, N'RULE', N'SENSOR_FAULT');
SET @alert = SCOPE_IDENTITY();
EXEC Ticket_OpenForFault 1, @alert, @sess, N'weight_delta_g=-5000 is outside the valid range';
EXEC Ticket_OpenForFault 1, @alert, @sess, N'second fault must not add a ticket';
SELECT @n = COUNT(*) FROM MaintenanceTicket WHERE status = N'OPEN';
SET @ok = CASE WHEN (@n = 1) THEN 1 ELSE 0 END; SET @dt = CAST(@n AS NVARCHAR(300)); EXEC #chk 'one open ticket per device', @ok, @dt;
SELECT @st = status FROM LockerSlot WHERE locker_slot_id = @a01;
SET @ok = CASE WHEN (@st = N'MAINTENANCE') THEN 1 ELSE 0 END; SET @dt = CAST(@st AS NVARCHAR(300)); EXEC #chk 'slot goes to MAINTENANCE', @ok, @dt;
SELECT @st = display_status FROM v_LockerSlotMap WHERE slot_id = @a01;
SET @ok = CASE WHEN (@st = N'MAINTENANCE') THEN 1 ELSE 0 END; SET @dt = CAST(@st AS NVARCHAR(300)); EXEC #chk 'map shows MAINTENANCE', @ok, @dt;
SELECT @n = COUNT(*) FROM MaintenanceTicket t JOIN UserRole ur ON ur.user_id = t.assigned_to JOIN Roles r ON r.role_id = ur.role_id WHERE r.role_name = N'TECHNICIAN';
SET @ok = CASE WHEN (@n = 1) THEN 1 ELSE 0 END; SET @dt = CAST(@n AS NVARCHAR(300)); EXEC #chk 'assigned to a technician', @ok, @dt;
INSERT INTO LockerSessionLabel (session_id, label) VALUES (@sess, N'FORCED_OPEN');
SELECT @n = COUNT(*) FROM v_LockerSession_Features WHERE session_id = @sess;
SET @ok = CASE WHEN (@n = 0) THEN 1 ELSE 0 END; SET @dt = CAST(@n AS NVARCHAR(300)); EXEC #chk 'SENSOR_FAULT session is kept out of training data', @ok, @dt;
SELECT @tick = ticket_id FROM MaintenanceTicket WHERE status = N'OPEN';
DECLARE @tech INT = (SELECT user_id FROM Users WHERE username = N'tech1');
EXEC Ticket_Close @tick, @tech, N'Recalibrated the load cell';
SELECT @st = status FROM LockerSlot WHERE locker_slot_id = @a01;
SET @ok = CASE WHEN (@st = N'AVAILABLE') THEN 1 ELSE 0 END; SET @dt = CAST(@st AS NVARCHAR(300)); EXEC #chk 'closing the ticket frees the slot', @ok, @dt;
SELECT @st = status FROM Alert WHERE alert_id = @alert;
SET @ok = CASE WHEN (@st = N'RESOLVED') THEN 1 ELSE 0 END; SET @dt = CAST(@st AS NVARCHAR(300)); EXEC #chk 'closing the ticket resolves the alert', @ok, @dt;
BEGIN TRY EXEC Ticket_Close @tick, @tech; SET @ok = 0; SET @dt = CAST('no error' AS NVARCHAR(300)); EXEC #chk 'closed ticket cannot be closed again', @ok, @dt;
END TRY BEGIN CATCH SET @ok = CASE WHEN ERROR_NUMBER() = 50040 THEN 1 ELSE 0 END; SET @dt = CAST(ERROR_MESSAGE() AS NVARCHAR(300)); EXEC #chk 'closed ticket cannot be closed again', @ok, @dt; END CATCH
BEGIN TRY UPDATE LockerSession SET stay_min = 1 WHERE session_id = @sess; SET @ok = 0; SET @dt = CAST('no error' AS NVARCHAR(300)); EXEC #chk 'sessions are append-only', @ok, @dt;
END TRY BEGIN CATCH SET @ok = 1; SET @dt = CAST('' AS NVARCHAR(300)); EXEC #chk 'sessions are append-only', @ok, @dt; END CATCH

PRINT '=== Audit';
SELECT @n = COUNT(*) FROM AuditLog;
SELECT @x = COUNT(*) FROM HashChain;
SET @ok = CASE WHEN (@n = @x) THEN 1 ELSE 0 END; SET @dt = CAST(@n AS NVARCHAR(300)); EXEC #chk 'every audit row has a chain row', @ok, @dt;
PRINT 'audit rows: ' + CAST(@n AS VARCHAR(10));
GO
