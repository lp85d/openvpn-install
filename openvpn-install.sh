#!/bin/bash
[ $EUID -ne 0 ] && echo "Run as root." && exit 1

NIC=$(ip -o -4 route show to default | awk '{print $5}')
IP=$(ip -o -4 addr list $NIC | awk '{print $4}' | cut -d/ -f1)

apt update && apt install -y openvpn easy-rsa
make-cadir /etc/openvpn/easy-rsa && cd /etc/openvpn/easy-rsa
./easyrsa init-pki && echo -en "\n\n\n\n" | ./easyrsa build-ca nopass
./easyrsa gen-dh && ./easyrsa gen-req server nopass
./easyrsa sign-req server server && openvpn --genkey --secret pki/ta.key
./easyrsa build-client-full client1 nopass

cat > /etc/openvpn/server.conf <<EOF
port 1194
proto udp
dev tun
ca pki/ca.crt
cert pki/issued/server.crt
key pki/private/server.key
dh pki/dh.pem
tls-auth pki/ta.key 0
keepalive 10 120
persist-key
persist-tun
status openvpn-status.log
verb 3
EOF

iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o $NIC -j MASQUERADE

cat > /etc/systemd/system/openvpn.service <<EOF
[Unit]
Description=OpenVPN service
After=network.target
[Service]
ExecStart=/usr/sbin/openvpn --config /etc/openvpn/server.conf
Restart=always
[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload && systemctl enable openvpn && systemctl start openvpn

cat > /etc/openvpn/client.ovpn <<EOF
client
dev tun
proto udp
remote $IP 1194
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
cipher AES-256-CBC
verb 3
<ca>
$(cat /etc/openvpn/easy-rsa/pki/ca.crt)
</ca>
<cert>
$(cat /etc/openvpn/easy-rsa/pki/issued/client1.crt)
</cert>
<key>
$(cat /etc/openvpn/easy-rsa/pki/private/client1.key)
</key>
<tls-auth>
$(cat /etc/openvpn/easy-rsa/pki/ta.key)
</tls-auth>
EOF

echo "OpenVPN setup complete. Client config: /etc/openvpn/client.ovpn"
