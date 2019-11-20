# IPsec-L2TP サーバ(AWS Ubuntu 18.04)

* EC2に設置したopenswan, xl2tpdサーバで、内部ネットワークにアクセス可能にさせる

## IPsec-L2TP

項目 | 値
-----|----
eth0 のIPアドレス | 172.32.0.10
VPNのリンクネットワーク | 192.168.2.0/26
VPNのサーバIPアドレス | 192.168.2.1
DNSサーバ(AmazonProvidedDNS) | 172.32.0.2
DNSサーバ(dnsmasq) | 192.168.2.1

[AmazonProvidedDNSはAWSの内部DNSサーバで、VPC IPv4 ネットワークの範囲に 2 をプラスした値です](https://docs.aws.amazon.com/ja_jp/vpc/latest/userguide/VPC_DHCP_Options.html#AmazonDNS)。VPCのCIDRが 172.32.0.0/16 の場合は **172.32.0.2** となります。

以下の例で 

	$ sudo apt install strongswan xl2tpd ike-scan

	$ sudo sh -c 'cat > /etc/ipsec.conf' << 'EOS'
	config setup
	
	conn %default
	  ikelifetime=60m
	  keylife=20m
	  rekeymargin=3m
	  keyingtries=1
	
	conn l2tp
	  keyexchange=ikev1
	  auto=add
	  type=transport
	  authby=secret

	  # Prefer modern cipher suites that allow PFS (Perfect Forward Secrecy)
	  ike=aes128-sha256-ecp256,aes256-sha384-ecp384,aes128-sha256-modp2048,aes128-sha1-modp2048,aes256-sha384-modp4096,aes256-sha256-modp4096,aes256-sha1-modp4096,aes128-sha256-modp1536,aes128-sha1-modp1536,aes256-sha384-modp2048,aes256-sha256-modp2048,aes256-sha1-modp2048,aes128-sha256-modp1024,aes128-sha1-modp1024,aes256-sha384-modp1536,aes256-sha256-modp1536,aes256-sha1-modp1536,aes256-sha384-modp1024,aes256-sha256-modp1024,aes256-sha1-modp1024!

	  esp=aes128gcm16-ecp256,aes256gcm16-ecp384,aes128-sha256-ecp256,aes256-sha384-ecp384,aes128-sha256-modp2048,aes128-sha1-modp2048,aes256-sha384-modp4096,aes256-sha256-modp4096,aes256-sha1-modp4096,aes128-sha256-modp1536,aes128-sha1-modp1536,aes256-sha384-modp2048,aes256-sha256-modp2048,aes256-sha1-modp2048,aes128-sha256-modp1024,aes128-sha1-modp1024,aes256-sha384-modp1536,aes256-sha256-modp1536,aes256-sha1-modp1536,aes256-sha384-modp1024,aes256-sha256-modp1024,aes256-sha1-modp1024,aes128gcm16,aes256gcm16,aes128-sha256,aes128-sha1,aes256-sha384,aes256-sha256,aes256-sha1!
	
	  left=%any
	  leftsubnet=0.0.0.0/0
	  leftprotoport=17/1701
	  leftfirewall=no
	
	  right=%any
	  rightprotoport=17/%any
	
	EOS

	$ sudo sh -c 'cat > /etc/ipsec.secrets' << 'EOS'
	: PSK "コンピュータ認証の共有パスワード"
	EOS

	$ sudo sh -c 'cat > /etc/xl2tpd/xl2tpd.conf' << 'EOS'
	[global]
	port = 1701
	
	[lns default]
	; 192.168.2.0/26
	local ip = 192.168.2.1
	ip range = 192.168.2.2-192.168.2.62
	
	require chap = yes
	refuse pap = yes
	length bit = yes
	require authentication = yes
	pppoptfile = /etc/ppp/options.xl2tpd
	name = l2tp
	EOS

DNSサーバのIPアドレスは、後述のdnsmasqを設定した場合、自分自身のeth0のアドレスとなる。

	$ sudo sh -c 'cat > /etc/ppp/options.xl2tpd' << 'EOS'
	name l2tp
	
	refuse-pap
	refuse-chap
	refuse-mschap
	require-mschap-v2
	noccp
	
	ms-dns DNSサーバ
	defaultroute
	
	debug
	lock
	nobsdcomp
	mtu 1240
	mru 1240
	
	logfile /var/log/xl2tpd.log
	EOS

	$ sudo sh -c 'cat > /etc/ppp/chap-secrets' << 'EOS'
	# Secrets for authentication using CHAP
	# client        server  secret                  IP addresses
	"ユーザ名" * "ユーザ認証のパスワード" *
	EOS

	$ sudo systemctl restart ipsec
	$ sudo systemctl restart xl2tpd

## iptables

	$ iptables -A INPUT -i $PUBIF -p 50 -j ACCEPT               # IPsec ESP
	$ iptables -A INPUT -i $PUBIF -p 51 -j ACCEPT               # IPsec AH
	$ iptables -A INPUT -i $PUBIF -p udp --dport 500  -j ACCEPT # IPsec IKE
	$ iptables -A INPUT -i $PUBIF -p udp --dport 4500 -j ACCEPT # IPsec NAT Traversal
	$ iptables -A INPUT -i $PUBIF -p udp --dport 1701 -j ACCEPT # L2TP
	$ iptables -A INPUT -i ppp+ -p icmp --icmp-type 0 -j ACCEPT # ICMP Echo Reply
	$ iptables -A INPUT -i ppp+ -p icmp --icmp-type 8 -j ACCEPT # ICPM Echo Message
	$ iptables -A INPUT -i ppp+ -p tcp --dport 22 -j ACCEPT # SSH
	$ iptables -A INPUT -i ppp+ -p tcp --dport 53 -j ACCEPT # DNS
	$ iptables -A INPUT -i ppp+ -p udp --dport 53 -j ACCEPT # DNS
	$ iptables -t nat -A POSTROUTING -o eth0 -s 192.168.2.0/26 -j MASQUERADE

## dnsmasq

dnsmasqでAmazonProvidedDNSをリレーします。dnsmasqを使わずに、AmazonProvidedDNSを直接指定するだけで済むなら、そちらのほうが楽かもしれません。DNS偽装などができるため便利です。

	$ sudo apt install dnsmasq

	$ sudo sh -c 'cat > /etc/dnsmasq.conf' << 'EOS'
	port=53
	resolv-file=/etc/resolv.dnsmasq.conf
	bind-interfaces
	no-dhcp-interface=lo,eth0,ppp+
	EOS

VPCのCIDRを得る

	$ curl --retry 3 --silent --fail http://169.254.169.254/latest/meta-data/network/interfaces/macs/$( cat /sys/class/net/eth0/address )/vpc-ipv4-cidr-block && echo ""

dnsmasq設定続き

	$ sudo sh -c 'cat > /etc/resolv.dnsmasq.conf' << 'EOS'
	nameserver 172.32.0.2
	EOS

	$ sudo sh -c 'cat > /etc/resolv.conf' << 'EOS'
	nameserver 127.0.0.1
	EOS

	$ sudo systemctl restart dnsmasq

新しい接続があったらdnsmasqを再起動する必要がある(ppp+が有効にならない)

	$ sudo sh -c 'cat > /etc/ppp/ip-up.d/dnsmasq' << 'EOS'
	#!/bin/sh -e
	if [ "$IFACE" = "lo" ]; then
	        exit 0
	fi
	service dnsmasq restart
	EOS

	$ sudo chmod 755 /etc/ppp/ip-up.d/dnsmasq


