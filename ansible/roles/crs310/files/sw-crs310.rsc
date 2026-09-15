# software id = WIWK-M5F5
#
# model = CRS310-8G+2S+
# serial number = HEZ099TEMQQ
/interface bridge
add admin-mac=78:9A:18:43:05:AD auto-mac=no comment=defconf name=bridge \
    port-cost-mode=short vlan-filtering=yes
/interface ethernet
set [ find default-name=ether3 ] name=asarim
set [ find default-name=ether4 ] name=bmc-asarim
set [ find default-name=ether7 ] name=guest
set [ find default-name=ether6 ] name=guest-spare
set [ find default-name=ether8 ] name=pc-clem
set [ find default-name=ether5 ] name=pve-5
set [ find default-name=ether2 ] name=tmp-trunk-to-uplink
set [ find default-name=ether1 ] name=trunk-to-uplink
/interface vlan
add comment=servers interface=bridge name=VLAN42 vlan-id=42
add comment=bmc interface=bridge name=VLAN52 vlan-id=52
add comment=vms interface=bridge name=VLAN62 vlan-id=62
add comment=guest interface=bridge name=VLAN69 vlan-id=69
add comment=vips interface=bridge name=VLAN72 vlan-id=72
/interface list
add name=WAN
add name=LAN
/interface wireless security-profiles
set [ find default=yes ] supplicant-identity=MikroTik
/port
set 0 name=serial0
/interface bridge port
add bridge=bridge comment=defconf interface=trunk-to-uplink \
    internal-path-cost=10 path-cost=10
add bridge=bridge comment=defconf interface=tmp-trunk-to-uplink \
    internal-path-cost=10 path-cost=10
add bridge=bridge comment=defconf interface=asarim internal-path-cost=10 \
    path-cost=10 pvid=42
add bridge=bridge comment=defconf interface=bmc-asarim internal-path-cost=10 \
    path-cost=10 pvid=52
add bridge=bridge comment=defconf interface=pve-5 internal-path-cost=10 \
    path-cost=10 pvid=42
add bridge=bridge comment=defconf interface=guest-spare internal-path-cost=10 \
    path-cost=10 pvid=69
add bridge=bridge comment=defconf interface=guest internal-path-cost=10 \
    path-cost=10 pvid=69
add bridge=bridge comment=defconf interface=pc-clem internal-path-cost=10 \
    path-cost=10 pvid=69
add bridge=bridge comment=defconf interface=sfp-sfpplus1 internal-path-cost=\
    10 path-cost=10
add bridge=bridge comment=defconf interface=sfp-sfpplus2 internal-path-cost=\
    10 path-cost=10
/ip firewall connection tracking
set udp-timeout=10s
/interface bridge vlan
add bridge=bridge tagged=trunk-to-uplink untagged=asarim,pve-5 vlan-ids=42
add bridge=bridge tagged=trunk-to-uplink untagged=bmc-asarim vlan-ids=52
add bridge=bridge tagged=trunk-to-uplink untagged=asarim,pve-5 vlan-ids=62
add bridge=bridge tagged=trunk-to-uplink untagged=guest,pc-clem,guest-spare \
    vlan-ids=69
add bridge=bridge tagged=bridge vlan-ids=42,52,62,69,72
add bridge=bridge tagged=trunk-to-uplink,tmp-trunk-to-uplink untagged=bridge \
    vlan-ids=1
/interface list member
add interface=trunk-to-uplink list=WAN
add interface=tmp-trunk-to-uplink list=LAN
add interface=asarim list=LAN
add interface=bmc-asarim list=LAN
add interface=pve-5 list=LAN
add interface=guest-spare list=LAN
add interface=guest list=LAN
add interface=pc-clem list=LAN
add interface=sfp-sfpplus1 list=LAN
add interface=sfp-sfpplus2 list=LAN
/ip dhcp-client
add interface=bridge
add comment="mgmt via .42.62 reservation" interface=VLAN42
/ip hotspot profile
set [ find default=yes ] html-directory=hotspot
/ip ipsec profile
set [ find default=yes ] dpd-interval=2m dpd-maximum-failures=5
/system note
set show-at-login=no
