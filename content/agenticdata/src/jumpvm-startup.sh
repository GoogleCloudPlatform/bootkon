#!/bin/bash
# Startup script for the cymbal-jump VM: forwards port 5432 to the Cymbal
# database at the PSC endpoint (10.10.0.5) via iptables DNAT. Linux startup
# scripts run on every boot, so the rules survive VM restarts.
sysctl -w net.ipv4.ip_forward=1
iptables -t nat -F
iptables -t nat -A PREROUTING -p tcp --dport 5432 -j DNAT --to-destination 10.10.0.5
iptables -t nat -A POSTROUTING -p tcp --dport 5432 -j MASQUERADE
