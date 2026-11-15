-- Evidence: what the server stored since $(since) (UTC). Run: sqlcmd ... -I -W -v since="yyyy-mm-dd hh:mm:ss" -i snapshot.sql
SET NOCOUNT ON;
DECLARE @since DATETIME2 = '$(since)';
PRINT '-- LockerSession (+ label) ingested since ' + CONVERT(VARCHAR(30), @since, 121);
SELECT s.session_id, d.device_code, s.device_seq, s.ingested_at, ls.slot_code, s.card_uid, s.open_source, s.command_id,
       s.door_open_sec, s.weight_delta_g, s.rfid_ok, l.label AS session_label
FROM LockerSession s JOIN Device d ON d.device_id = s.device_id
LEFT JOIN LockerSlot ls ON ls.locker_slot_id = s.slot_id
LEFT JOIN LockerSessionLabel l ON l.session_id = s.session_id
WHERE s.ingested_at >= @since ORDER BY s.session_id;
PRINT '-- Alert since';
SELECT a.alert_id, d.device_code, a.session_id, a.source, a.label, a.risk_score, a.status, a.created_at
FROM Alert a LEFT JOIN Device d ON d.device_id = a.device_id WHERE a.created_at >= @since ORDER BY a.alert_id;
PRINT '-- AlertEvidence of those alerts';
SELECT e.alert_id, e.item, LEFT(e.value_text, 80) AS value_text FROM AlertEvidence e JOIN Alert a ON a.alert_id = e.alert_id
WHERE a.created_at >= @since ORDER BY e.alert_id, e.evidence_id;
PRINT '-- MaintenanceTicket opened since';
SELECT t.ticket_id, t.alert_id, d.device_code, t.status, t.opened_at, LEFT(t.note, 80) AS note
FROM MaintenanceTicket t LEFT JOIN Device d ON d.device_id = t.device_id WHERE t.opened_at >= @since ORDER BY t.ticket_id;
PRINT '-- RemoteCommand created since';
SELECT c.command_id, d.device_code, c.slot_id, c.action, c.status, c.source, c.created_at, c.sent_at, c.done_at, c.session_id
FROM RemoteCommand c JOIN Device d ON d.device_id = c.device_id WHERE c.created_at >= @since ORDER BY c.command_id;
PRINT '-- Deposit changes (LIB-A)';
SELECT dp.deposit_id, u.username, ls.slot_code, dp.status, dp.reserved_at, dp.hold_until
FROM Deposit dp JOIN Users u ON u.user_id = dp.user_id JOIN LockerSlot ls ON ls.locker_slot_id = dp.slot_id
WHERE ls.bank_id = (SELECT bank_id FROM LockerBank WHERE bank_code = N'LIB-A') AND dp.reserved_at >= DATEADD(DAY, -1, @since);
PRINT '-- Device LOCKER-01 now';
SELECT device_code, status, last_seen, firmware, SYSUTCDATETIME() AS now_utc FROM Device WHERE device_code = N'LOCKER-01';
