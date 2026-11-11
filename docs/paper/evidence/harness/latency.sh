#!/bin/sh
# Evidence: server-side response time of the device API, measured with curl time_total from this machine (localhost).
# Usage (repo root): PIN=<6-digit PIN of an ACTIVE booking on a bank of LOCKER-01> N=30 sh docs/paper/evidence/harness/latency.sh
B=http://localhost:8080/SmartLocker
KEY=$(grep '^LOCKER-01=' config/device-keys.local.properties | cut -d= -f2- | tr -d '\r')
N=${N:-30}
run() {  # name, url, body, with-key
  echo "### $1: $N x POST $2 body=$(echo "$3" | sed "s/$PIN/<pin>/g")"
  for i in $(seq 1 $N); do
    if [ "$4" = key ]; then
      out=$(curl -s -o "$H/lat.body" -w "%{http_code} %{time_total}" -H "X-API-Key: $KEY" -H "Content-Type: application/json" -d "$3" "$2")
    else
      out=$(curl -s -o "$H/lat.body" -w "%{http_code} %{time_total}" -H "Content-Type: application/json" -d "$3" "$2")
    fi
    echo "RAW $1 $i $out $(head -c 90 $H/lat.body | sed "s/$PIN/<pin>/g")"
  done
}
H=docs/paper/evidence/harness
# one warm-up call per endpoint (JIT, connection pool) is not counted
curl -s -o /dev/null -H "X-API-Key: $KEY" -H "Content-Type: application/json" -d '{"firmware":"sim-1.0","uptime_sec":60}' $B/api/health
run health "$B/api/health" '{"firmware":"sim-1.0","uptime_sec":60}' key
run auth_pin_ask "$B/api/device/auth" "{\"method\":\"PIN\",\"pin\":\"$PIN\",\"intent\":\"ASK\"}" key
run kiosk_ask "$B/api/kiosk/unlock" "{\"device_code\":\"LOCKER-01\",\"pin\":\"$PIN\",\"intent\":\"ASK\"}" nokey
rm -f $H/lat.body
