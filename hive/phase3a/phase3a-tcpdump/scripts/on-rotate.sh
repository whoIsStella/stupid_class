#!/usr/bin/env bash
# on-rotate.sh — called by tcpdump -z when a capture file is completed
# Touches a .done sentinel so compress-pcaps.sh knows the file is safe to compress.
# $1 = completed pcap file path (passed by tcpdump)
touch "${1}.done"
