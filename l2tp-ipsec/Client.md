# Psec-L2TP クライアント

## macOS High Sierra

システム環境設定 → ネットワーク → ＋

項目 | 値
-----|----
インターフェイス | VPN
VPNタイプ | L2TP over IPSec
サービス名 | 任意の名前
サーバアドレス | サーバホスト名
アカウント名 | アカウント名

認証設定

項目 | 値
-----|----
ユーザ認証-パスワード | ユーザパスワード
コンピュータ認証-共有シークレット | PSK

詳細 → すべてのトラフィックをVPN接続経由で送信

## iPhone6

設定 → 一般 → VPN → VPN構成を追加

項目 | 値
-----|----
タイプ | L2TP
説明 | 任意の名前
サーバ | サーバホスト名
アカウント | アカウント名
パスワード | ユーザパスワード
シークレット | PSK
すべての信号を送信 | ON

## Windows10

事前に[このレジストリキー](AssumeUDPEncapsulationContextOnSendRule.reg)を適用しておく必要がある。

設定 → ネットワークとインターネット → VPN → VPN接続を追加する

項目 | 値
-----|----
VPNプロバイダー | Windows(ビルトイン)
接続名 | 任意の名前
サーバ名またはアドレス | サーバホスト名
VPNの種類 | 事前共有キーを使ったL2TP/IPsec
事前共有キー | PSK
サインイン情報と種類 | ユーザ名とパスワード
ユーザ名 | アカウント名
パスワード | ユーザーパスワード

## Android9

準備中

## Debian Buster(手動設定)

以下の設定を行うと既存の設定はすべて上書きされますのでご注意ください

### インストール

	$ sudo apt install -y strongswan xl2tpd

### 設定と接続

	$ sudo bash -xe << 'END_OF_SNIPPETS'
	
	L2TP_IPSEC_HOST="サーバホスト名"
	L2TP_IPSEC_USER="アカウント名"
	L2TP_IPSEC_PASS="ユーザーパスワード"
	L2TP_IPSEC_PSK="PSK"
	
	L2TP_IPSEC_IPADDR=$(getent hosts $L2TP_IPSEC_HOST | awk '{print $1}')
	
	cat > /etc/ipsec.conf << EOS
	conn %default
		ikelifetime=60m
		keylife=20m
		rekeymargin=3m
		keyingtries=1
	
	conn l2tp
		keyexchange=ikev1
		authby=secret
		auto=start
		type=transport
	
		right=$L2TP_IPSEC_IPADDR
		rightprotoport=17/1701
		rightid=%any
	
		left=%defaultroute
		leftprotoport=17/1701
		leftfirewall=yes
	EOS
	
	cat > /etc/ipsec.secrets << EOS
	$L2TP_IPSEC_IPADDR : PSK "$L2TP_IPSEC_PSK"
	EOS
	
	cat > /etc/xl2tpd/xl2tpd.conf << EOS
	[lac l2tp]
	lns = $L2TP_IPSEC_IPADDR
	pppoptfile = /etc/ppp/options.l2tpd.client
	length bit = yes
	autodial = yes
	redial = yes
	redial timeout = 10
	max redials = 6
	EOS
	
	cat > /etc/ppp/options.l2tpd.client << EOS
	name $L2TP_IPSEC_USER
	password $L2TP_IPSEC_PASS
	noauth
	mtu 1410
	mru 1410
	defaultroute
	persist
	EOS
	
	systemctl restart ipsec
	sleep 3
	ipsec status
	systemctl restart xl2tpd
	sleep 3
	ip addr show
	END_OF_SNIPPETS

### すべての通信をVPN経由にするルーティング

この設定は起動時毎回実行する必要がある

	$ sudo bash -xe << 'END_OF_SNIPPETS'

	L2TP_IPSEC_HOST="サーバホスト名"
	# VPNで接続されているpppデバイス
	L2TP_IPSEC_DEV=ppp0
	
	L2TP_IPSEC_IPADDR=$(getent hosts $L2TP_IPSEC_HOST | awk '{print $1}')
	ORIGINAL_DEFAULT_GW=$( ip route list | grep default | awk '{ print $3 }' )
	VPN_DEFAULT_GW=$(ip addr show $L2TP_IPSEC_DEV | grep inet | awk '{ print $4 }')
	
	ip route add $L2TP_IPSEC_IPADDR/32 via $ORIGINAL_DEFAULT_GW
	ip route del default
	ip route add default via ${VPN_DEFAULT_GW%%/32}
	
	END_OF_SNIPPETS

確認、VPNサーバ側のアドレスになっていればOK

	$ curl https://httpbin.org/ip

### DNS

VPNサーバ自身がDNSサーバとなっている

	$ sudo bash -xe << 'EOS'
	DEFAULT_GW=$( ip route list | grep default | awk '{ print $3 }' )
	echo "nameserver $DEFAULT_GW" > /etc/resolv.conf
	EOS

AWS内部ホスト名が取得できればOK

	$ dig hogehoge.aws

