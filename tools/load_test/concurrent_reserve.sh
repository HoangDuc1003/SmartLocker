#!/bin/sh
# Concurrency test of the booking procedures on a test database (SL_* only; never PRJ301_LOCKER).
# Race A: N different users call Deposit_Reserve for the SAME free slot at the same instant -> exactly one may win.
# Race B: ONE user calls Deposit_Reserve for M different free slots at the same instant -> exactly one may win
#         (filtered unique index: one open booking per user).
# Every call runs in its own sqlcmd process (own connection); all wait for the same server time (WAITFOR TIME).
# Usage (Git Bash, repo root): DB=SL_LOAD N=50 M=20 sh tools/load_test/concurrent_reserve.sh
set -eu
DB=${DB:?set DB=SL_...}; N=${N:-50}; M=${M:-20}
case "$DB" in SL_*) ;; *) echo "DB must be an SL_* test database" >&2; exit 2;; esac
Q="sqlcmd -S localhost -E -d $DB -I -h -1 -W -b"  # -I: QUOTED_IDENTIFIER ON, required by the filtered indexes
T=$(mktemp -d)
q() { $Q -Q "SET NOCOUNT ON; $1" | tr -d '\r'; }

PLAN=$(q "SELECT TOP 1 plan_id FROM StoragePlan WHERE duration_min=120 AND is_active=1 ORDER BY plan_id" | head -1)
# test database only: give the candidate users enough balance so that price is never the reason to fail
USERS=$(q "SELECT TOP ($N+1) u.user_id FROM Users u WHERE u.status=N'ACTIVE' AND u.username NOT IN (N'admin',N'operator1',N'tech1',N'auditor1')
           AND NOT EXISTS (SELECT 1 FROM Deposit d WHERE d.user_id=u.user_id AND d.status IN (N'RESERVED',N'ACTIVE'))
           ORDER BY u.user_id" | grep -E '^[0-9]+$')
q "UPDATE Users SET balance = 1000000 WHERE user_id IN ($(echo $USERS | tr ' ' ','))" >/dev/null
SLOTS=$(q "SELECT TOP ($M+1) s.locker_slot_id FROM LockerSlot s JOIN LockerBank b ON b.bank_id=s.bank_id
           JOIN Device d ON d.device_id=b.device_id WHERE s.status=N'AVAILABLE' AND d.status<>N'OFFLINE'
           ORDER BY s.locker_slot_id" | grep -E '^[0-9]+$')
SLOT_A=$(echo "$SLOTS" | head -1)
USER_B=$(echo "$USERS" | tail -1)
USERS_A=$(echo "$USERS" | head -$N)
SLOTS_B=$(echo "$SLOTS" | tail -$M)
echo "# db=$DB plan=$PLAN race A: $(echo $USERS_A | wc -w) users -> slot $SLOT_A ; race B: user $USER_B -> $(echo $SLOTS_B | wc -w) slots"

race() {  # name, list of "user slot" pairs
  name=$1; shift
  AT=$(q "SELECT CONVERT(VARCHAR(12), CAST(DATEADD(SECOND, 6, SYSDATETIME()) AS TIME), 114)" | head -1)
  i=0
  while [ $# -gt 1 ]; do  # no pipeline here: the background jobs must belong to this shell so that wait sees them
    u=$1; s=$2; shift 2; i=$((i+1))
    $Q -Q "SET NOCOUNT ON; WAITFOR TIME '$AT'; DECLARE @id BIGINT;
      BEGIN TRY EXEC Deposit_Reserve $u, $s, $PLAN, @id OUTPUT, N'PIN'; PRINT 'OK user=$u slot=$s deposit=' + CAST(@id AS VARCHAR(20)); END TRY
      BEGIN CATCH PRINT 'REFUSED user=$u slot=$s error=' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + ' ' + LEFT(ERROR_MESSAGE(), 80); END CATCH" \
      > "$T/$name.$i.out" 2>&1 &
  done
  wait
  echo "## race $name started together at server time $AT"
  cat "$T"/$name.*.out | tr -d '\r' | grep -E '^(OK|REFUSED)' | sed -E 's/user=[0-9]+ slot=[0-9]+ //; s/deposit=[0-9]+/deposit=<id>/' | sort | uniq -c | sed 's/^ *//'
  cat "$T"/$name.*.out | tr -d '\r' | grep -E '^OK'
  echo "OK=$(cat "$T"/$name.*.out | grep -c '^OK') REFUSED=$(cat "$T"/$name.*.out | grep -c '^REFUSED') CALLS=$(ls "$T"/$name.*.out | wc -l)"
}
PAIRS_A=$(for u in $USERS_A; do printf '%s %s ' "$u" "$SLOT_A"; done)
PAIRS_B=$(for s in $SLOTS_B; do printf '%s %s ' "$USER_B" "$s"; done)
BAL0=$(q "SELECT SUM(CAST(balance AS BIGINT)) FROM Users WHERE user_id IN ($(echo $USERS | tr ' ' ','))" | head -1)
race A $PAIRS_A
race B $PAIRS_B
echo "## database afterwards"
q "SELECT 'open bookings on slot $SLOT_A: ' + CAST(COUNT(*) AS VARCHAR) FROM Deposit WHERE slot_id=$SLOT_A AND status IN (N'RESERVED',N'ACTIVE')"
q "SELECT 'open bookings of user $USER_B: ' + CAST(COUNT(*) AS VARCHAR) FROM Deposit WHERE user_id=$USER_B AND status IN (N'RESERVED',N'ACTIVE')"
q "SELECT 'slot $SLOT_A status: ' + status FROM LockerSlot WHERE locker_slot_id=$SLOT_A"
BAL1=$(q "SELECT SUM(CAST(balance AS BIGINT)) FROM Users WHERE user_id IN ($(echo $USERS | tr ' ' ','))" | head -1)
PAID=$(q "SELECT SUM(CAST(paid_amount AS BIGINT)) FROM Deposit WHERE user_id IN ($(echo $USERS | tr ' ' ',')) AND status IN (N'RESERVED',N'ACTIVE')" | head -1)
echo "wallets before=$BAL0 after=$BAL1 charged=$((BAL0-BAL1)) paid_amount of open bookings=$PAID"
rm -rf "$T"
