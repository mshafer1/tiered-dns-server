#!/bin/bash
# Path: ~/pihole/configure-lists.sh

# Insert or update your lists with comments and enabled states (1 = active, 0 = disabled)
pihole-FTL sqlite3 "$DB_PATH" <<EOF
INSERT OR REPLACE INTO adlist (address, enabled, comment) VALUES 
('https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/adblock/fake.txt', 1, 'Scams, traps, and fake sites'),
('https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/adblock/tif.txt', 1, 'threat-intelligence-feed (TIF) blocks domains known for spreading malware, running phishing attacks, and hosting command-and-control servers.'),
('https://cdn.jsdelivr.net/gh/hagezi/nrd@latest/adblock/nrd7.txt', 1, '1-7 day new domains'),
('https://cdn.jsdelivr.net/gh/hagezi/nrd@latest/adblock/nrd14-8.txt', 1, '8-14 day new domains'),
('https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/adblock/dyndns.txt', 1, 'Blocks dynamic DNS services'),
('https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/adblock/doh-vpn-proxy-bypass.txt', 1, 'Blocks sites about DOH, VPN, and proxy bypass'),
('https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/adblock/hoster.txt', 1, 'Blocks badware hosting sites'),
('https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/adblock/anti.piracy.txt', 1, 'Blocks sites about piracy, torrents, and illegal downloads'),
('https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/adblock/nsfw.txt', 1, 'Blocks "adult" content sites'),
('https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/porn/hosts', 1, 'Adware, malware, and porn sites'),
('https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/fakenews-only/hosts', 1, 'Blocks fake news sites');
EOF

pihole -g
