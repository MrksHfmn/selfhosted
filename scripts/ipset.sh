#!/bin/bash

MAXELEM="200000"
BLOCKLIST="/tmp/firehol.txt"

# Download blocklists
curl -k https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/firehol_level1.netset >"$BLOCKLIST"
curl -k https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/firehol_level2.netset >>"$BLOCKLIST"
curl -k https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/firehol_level3.netset >>"$BLOCKLIST"
curl -k https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/firehol_abusers_1d.netset >>"$BLOCKLIST"
curl -k https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/blocklist_de.ipset >>"$BLOCKLIST"
curl -k https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/dshield_top_1000.ipset >>"$BLOCKLIST"
curl -k https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/nullsecure.ipset >>"$BLOCKLIST"
curl -k https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/bi_any_0_1d.ipset >>"$BLOCKLIST"
curl -k https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/malwaredomainlist.ipset >>"$BLOCKLIST"
curl -k https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/dshield.netset >>"$BLOCKLIST"
curl -k https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/blocklist_net_ua.ipset >>"$BLOCKLIST"

sync && sleep 2

# Remove everything starting with punctation
sed -i '/^[[:punct:]]/ d' "$BLOCKLIST"

# IPv4 addresses only
sed -i -n '/\([0-9]\{1,3\}\.\)\{3\}[0-9]\{1,3\}/p' "$BLOCKLIST"

# Remove Bogon IPs
sed -i '/127.0.0./d' "$BLOCKLIST"
sed -i '/0.0.0./d' "$BLOCKLIST"
sed -i '/10.0.0./d' "$BLOCKLIST"
sed -i '/172.16.0./d' "$BLOCKLIST"
sed -i '/192.0.0./d' "$BLOCKLIST"
sed -i '/192.0.2./d' "$BLOCKLIST"
sed -i '/192.168.0./d' "$BLOCKLIST"
sed -i '/192.168.1./d' "$BLOCKLIST"
sed -i '/192.178.168./d' "$BLOCKLIST"

# Unique IPs
grep -oe '^.*\S' "$BLOCKLIST" | sort | uniq >tmpFile && mv tmpFile "$BLOCKLIST"

ipset -L firehol >/dev/null 2>&1
if [ "$?" -ne 0 ]; then

	echo "No existing hashtable! Creating new one ..."
	ipset create firehol hash:net maxelem "$MAXELEM"

	# Drop with IPTables (control with journalctl -f | grep "FIREHOL")
	iptables -I INPUT -m set --match-set firehol src -j DROP
	iptables -I INPUT -m set --match-set firehol src -j LOG --log-prefix "[FIREHOL BLOCK] "
fi

echo "Hashtable exists! Filling now ..."
ipset flush firehol
while read -r ip; do ipset add firehol "$ip"; done <"$BLOCKLIST"

# Cleanup
echo "IPSet loaded with $(ipset -L | wc -l) IPs."
#rm "$BLOCKLIST"
