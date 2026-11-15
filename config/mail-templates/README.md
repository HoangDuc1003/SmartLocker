# Smart Locker Email Templates

Each `*.txt` file is an email template. Templates can be edited directly without recompiling; restart Tomcat to ensure new templates take effect.

## Format & Syntax

- First line: `Subject: Subject text` (supports placeholders `{{...}}`), followed by an empty line, then the email body.
- `{{variable_name}}` is replaced with the runtime value. If a variable is null or missing, it evaluates to an empty string.
- Lines starting with `?` are **optional lines**: the leading `?` is removed when sent, and the entire line is omitted if any variable on that line is empty (e.g. action links when `app.base_url` is unconfigured).
- `_footer.txt` is automatically appended to the end of all outgoing emails.
- Plain text only (no HTML). All injected values have newlines stripped and are capped at 300 characters to prevent injection attacks.
- `{{name}}` represents the recipient's full name; if empty, it defaults to "there" ("Hello there,"). All email content is strictly in English per PRJ301 specifications.

## Templates & Variables

| Template | Trigger / Event | Variables |
|---|---|---|
| `due_soon` | Booking due soon (15 minutes prior) -- **automated** | name, slot_code, bank_code, area_name, due_at, overdue_rate, my_locker_url |
| `overdue` | Overdue booking, slot locked | name, slot_code, bank_code, area_name, due_at, overdue_rate, overdue_hours, overdue_fee, balance, escalate_hours, topup_url, my_locker_url |
| `overdue_escalated` | Extended overdue escalated to staff | name, slot_code, bank_code, area_name, due_at, overdue_hours, overdue_fee, balance, my_locker_url |
| `booking_confirmed` | Slot booking confirmation | name, slot_code, bank_code, area_name, plan_name, open_method, amount, hold_until, my_locker_url |
| `reservation_expired` | Hold expired without arrival | name, slot_code, area_name, hold_min, refund_amount, refund_pct, map_url |
| `verification_code` | Email verification code | name, code, expires_min |
| `welcome` | New account registration | name, username, map_url, my_locker_url |
| `topup_approved` | Wallet top-up approved | name, amount, balance, topup_url |
| `topup_rejected` | Wallet top-up rejected | name, amount, reason, topup_url |
| `card_confirm` | Card scanned, awaiting opening confirmation -- **automated** | name, slot_code, bank_code, area_name, action, expires_min, confirm_url |
| `wrong_place` | Card scanned at wrong locker bank -- **automated** | name, slot_code, bank_code, area_name, map_url |

Time format follows standard local convention (`23/10/2026 16:00`), currency values are formatted as `14,700 VND`.

## Previewing Templates

```bash
sh scripts/mail-preview.sh list
sh scripts/mail-preview.sh due_soon
sh scripts/mail-preview.sh due_soon user@example.com
```

The second command prints rendered content using sample mock data; the third command sends a live test email to the specified address.
Currently, `due_soon`, `card_confirm`, and `wrong_place` are actively dispatched by background threads; other templates are production-ready for upcoming feature triggers.
