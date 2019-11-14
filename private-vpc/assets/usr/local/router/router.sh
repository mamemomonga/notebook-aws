#!/bin/bash
set -eu

BASEDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && cd .. && pwd )"
IPTABLES="iptables"
PUBIF="eth0"

PUBDEV_MAC=$( cat /sys/class/net/$PUBIF/address )
VPC_CIDR_RANGE=$(curl --retry 3 --silent --fail http://169.254.169.254/latest/meta-data/network/interfaces/macs/$PUBDEV_MAC/vpc-ipv4-cidr-block)
echo "PUBDEV_MAC: $PUBDEV_MAC"
echo "VPC_CIDR_RANGE: $VPC_CIDR_RANGE"

PUBDEV_IP=$(ip addr show eth0 | grep 'inet ' | awk '{print $2}' | perl -nlpE 's#/\d+$##')
echo "PUBDEV_IP: $PUBDEV_IP"

# IP転送
echo 0 > /proc/sys/net/ipv4/ip_forward

# syn flood攻撃対策
echo 1 > /proc/sys/net/ipv4/tcp_syncookies

# Smurf攻撃対策
echo 1 > /proc/sys/net/ipv4/icmp_echo_ignore_broadcasts

# ソースルートオプション付きパケットの不許可
echo 0 > /proc/sys/net/ipv4/conf/all/accept_source_route
echo 0 > /proc/sys/net/ipv4/conf/default/accept_source_route

# ICMP Redirect不許可
echo 0 > /proc/sys/net/ipv4/conf/all/accept_redirects
echo 0 > /proc/sys/net/ipv4/conf/default/accept_redirects

# ゲートウェイからのICMP Redirect不許可
echo 0 > /proc/sys/net/ipv4/conf/all/secure_redirects
echo 0 > /proc/sys/net/ipv4/conf/default/secure_redirects

# ICMPエラーメッセージを無視
echo 1 > /proc/sys/net/ipv4/icmp_ignore_bogus_error_responses

# UPTIMEを通知しない
echo 0 > /proc/sys/net/ipv4/tcp_timestamps

# 不正パケットのログ記録
echo 1 > /proc/sys/net/ipv4/conf/all/log_martians

# 送信元IPの偽装禁止
echo 1 > /proc/sys/net/ipv4/conf/all/rp_filter
echo 1 > /proc/sys/net/ipv4/conf/default/rp_filter

# RFC1337準拠(TCP接続待ち時間)
echo 1 > /proc/sys/net/ipv4/tcp_rfc1337

# DOS攻撃対策 FINパケット待ち時間
echo 30 > /proc/sys/net/ipv4/tcp_fin_timeout

# ICMP Redirectを送信しない
echo 0 > /proc/sys/net/ipv4/conf/$PUBIF/send_redirects

set -x

# リセット
$IPTABLES -t filter -F
$IPTABLES -t nat -F
$IPTABLES -t mangle -F
$IPTABLES -F
$IPTABLES -X

# デフォルトポリシー
$IPTABLES -t filter -P INPUT   DROP
$IPTABLES -t filter -P OUTPUT  ACCEPT
$IPTABLES -t filter -P FORWARD ACCEPT
$IPTABLES -t nat -P PREROUTING  ACCEPT
$IPTABLES -t nat -P POSTROUTING ACCEPT
$IPTABLES -t nat -P OUTPUT      ACCEPT

# すべて許可するポート
for i in lo; do
	$IPTABLES -A INPUT   -i $i -j ACCEPT
	$IPTABLES -A OUTPUT  -o $i -j ACCEPT
	$IPTABLES -A FORWARD -i $i -j ACCEPT
done

# ICMP
$IPTABLES -A INPUT -i $PUBIF -p icmp --icmp-type 0 -j ACCEPT
$IPTABLES -A INPUT -i $PUBIF -p icmp --icmp-type 8 -j ACCEPT

# TCP関連許可
$IPTABLES -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# $IPTABLES -t mangle -A FORWARD -o tun+ -p tcp --tcp-flags SYN,RST SYN -m tcpmss --mss 1280:65495 -j TCPMSS --clamp-mss-to-pmtu

# SSH
$IPTABLES -A INPUT -i $PUBIF -p tcp --dport 22 -j ACCEPT

# MASQUERADE
$IPTABLES -t nat -A POSTROUTING -o eth0 -s $VPC_CIDR_RANGE -j MASQUERADE

# IP転送
echo 1 > /proc/sys/net/ipv4/ip_forward

