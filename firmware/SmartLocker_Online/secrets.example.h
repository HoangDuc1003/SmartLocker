// Copy this file to secrets.h (same folder) and fill it in. secrets.h is in .gitignore: never commit it.

#define WIFI_SSID "your-wifi-name"
#define WIFI_PASS "your-wifi-password"

// LAN: the address of the PC running Tomcat. Also the fallback when CONFIG_URL cannot be read.
#define SERVER_BASE "http://192.168.137.1:8080/SmartLocker"

// Internet (Cloudflare tunnel): the fixed link of config.json, see docs/deploy.md. Leave it empty on a LAN.
#define CONFIG_URL ""

// The part after "LOCKER-01=" in config/device-keys.local.properties (scripts/set-device-key.ps1 creates it).
#define DEVICE_API_KEY "paste-the-device-key-here"
