#!/bin/sh
# Evidence: heartbeat scenario, then poll the DB every 2 s until LOCKER-01 has a new DEVICE_OFFLINE alert (max 240 s).
H=docs/paper/evidence/harness
DB="sqlcmd -S localhost -U sa -P 12345 -d PRJ301_LOCKER -I -W -h -1"
WAIT=0 sh $H/scenario.sh heartbeat
END=$($DB -Q "SET NOCOUNT ON; SELECT CONVERT(VARCHAR(23), SYSUTCDATETIME(), 126)" | tr -d '\r' | head -1)
echo "# heartbeats finished (DB UTC) $END; polling every 2 s for a DEVICE_OFFLINE alert of LOCKER-01 created after it"
for i in $(seq 1 120); do
  N=$($DB -Q "SET NOCOUNT ON; SELECT COUNT(*) FROM Alert a JOIN Device d ON d.device_id=a.device_id WHERE d.device_code='LOCKER-01' AND a.label='DEVICE_OFFLINE' AND a.created_at > '$END'" | tr -d '\r ' | head -1)
  [ "$N" != "0" ] && break
  sleep 2
done
echo "# poll result after $i polls:"
$DB -Q "SET NOCOUNT ON; SELECT 'last_seen='+CONVERT(VARCHAR(27), d.last_seen, 121)+'  alert_id='+CAST(a.alert_id AS VARCHAR)+'  alert.created_at='+CONVERT(VARCHAR(27), a.created_at, 121)+'  delta_ms='+CAST(DATEDIFF(MILLISECOND, d.last_seen, a.created_at) AS VARCHAR)+'  device.status='+d.status FROM Alert a JOIN Device d ON d.device_id=a.device_id WHERE d.device_code='LOCKER-01' AND a.label='DEVICE_OFFLINE' AND a.created_at > '$END'"
