echo "=== IPv4 Header ==="
(
  printf "Version\tLength\tTTL\tProtocol\tChecksum\tSource Address\n"
  tshark -r lab9_ipv4.pcap -Y icmp -T fields -e ip.version -e ip.hdr_len -e ip.ttl -e ip.proto -e ip.checksum -e ip.src -c 1 2>/dev/null
) | column -t -s $'\t' | sed 's/\t/ | /g'

echo -e "\n=== IPv6 Header ==="
(
  printf "Version\tPayload Len\tHop Limit\tNext Header\tSource Address\n"
  tshark -r lab9_ipv6.pcap -Y icmpv6 -T fields -e ipv6.version -e ipv6.plen -e ipv6.hlim -e ipv6.nxt -e ipv6.src -c 1 2>/dev/null
) | column -t -s $'\t' | sed 's/\t/ | /g'   
