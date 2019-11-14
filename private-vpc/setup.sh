#!/bin/bash
set -eu

if [ -e "config" ]; then
	source config
fi
if [ -e "vars" ]; then
	source vars
fi

save_vars() {
	cat > vars << EOS
ACCOUNT_ID="$ACCOUNT_ID"
VPC_SUBNET="$VPC_SUBNET"
VPC_NAME="$VPC_NAME"
VPC_DOMAIN_NAME="$VPC_DOMAIN_NAME"
VPC_REV="$VPC_REV"

VPC_ID=${VPC_ID:-}
RTB_PUBLIC=${RTB_PUBLIC:-}
RTB_PRIVATE=${RTB_PRIVATE:-}
SUBNET_1C_PUBLIC=${SUBNET_1C_PUBLIC:-}
SUBNET_1C_PRIVATE=${SUBNET_1C_PRIVATE:-}
SUBNET_1D_PUBLIC=${SUBNET_1D_PUBLIC:-}
SUBNET_1D_PRIVATE=${SUBNET_1D_PRIVATE:-}
SUBNET_1A_PUBLIC=${SUBNET_1A_PUBLIC:-}
SUBNET_1A_PRIVATE=${SUBNET_1A_PRIVATE:-}
INTERNET_GATEWAY=${INTERNET_GATEWAY:-}
VPC_DHCP_OPTIONS=${VPC_DHCP_OPTIONS:-}

GID_NAT_INSTANCE=${GID_NAT_INSTANCE:-}
MY_PUBLIC_IPADDR=${MY_PUBLIC_IPADDR:-}
GID_PRIVATE=${GID_PRIVATE:-}
EC2_ALLOCATION=${EC2_ALLOCATION:-}
EC2_INSTANCE=${EC2_INSTANCE:-}
EC2_PUBLIC_IP=${EC2_PUBLIC_IP:-}

EOS
	echo "Write: vars"
}

check_account_id() {
	if [ "$( aws sts get-caller-identity --query 'Account' --output text )" != "$ACCOUNT_ID" ]; then
		echo "AccountIDが合致しません"
		exit 1
	fi
	echo "AccountIDは正常です($ACCOUNT_ID)"
}

disp_default_vpc() {
	echo "デフォルトのVPC情報"
	aws ec2 describe-vpcs --filters 'Name=isDefault,Values=true' | jq '.Vpcs[] | { VpcId, CidrBlock }'
	aws ec2 describe-subnets | jq '.Subnets[] | {SubnetId,CidrBlock,AvailabilityZone}'
}

create_vpc() {
	echo "VPCの作成"
	VPC_ID=$(aws ec2 create-vpc --cidr-block $VPC_SUBNET --query "Vpc.VpcId" --output text)
	echo "VPC_ID: $VPC_ID"
	aws ec2 create-tags --resource $VPC_ID --tags 'Key=Name,Value='$VPC_NAME

	RTB_PUBLIC=$( aws ec2 describe-route-tables --query 'RouteTables[]' \
	  | jq -r '.[] | select(.Routes[].DestinationCidrBlock == "'$VPC_SUBNET'") | .RouteTableId' )
	echo "Public RouteTableID: $RTB_PUBLIC"
	aws ec2 create-tags --resource $RTB_PUBLIC --tags 'Key=Name,Value=Public'
}

create_subnet() {
	local name=$1
	local ipaddr=$2
	local az=$3
	local subnet_id=$( aws ec2 create-subnet \
	  --vpc-id            $VPC_ID \
	  --cidr-block        $ipaddr \
	  --availability-zone $az \
	  --query 'Subnet.SubnetId' --output text )
	aws ec2 create-tags --resources $subnet_id --tags "Key=Name,Value=$name"
	echo "$subnet_id"
}

create_subnets() {
	SUBNET_1C_PUBLIC=$(  create_subnet 1C-Public  172.32.0.0/21  ap-northeast-1c )
	SUBNET_1C_PRIVATE=$( create_subnet 1C-Private 172.32.8.0/21  ap-northeast-1c )
	SUBNET_1D_PUBLIC=$(  create_subnet 1D-Public  172.32.16.0/21 ap-northeast-1d )
	SUBNET_1D_PRIVATE=$( create_subnet 1D-Private 172.32.24.0/21 ap-northeast-1d )
	SUBNET_1A_PUBLIC=$(  create_subnet 1A-Public  172.32.32.0/21 ap-northeast-1a )
	SUBNET_1A_PRIVATE=$( create_subnet 1A-Private 172.32.40.0/21 ap-northeast-1a )

	echo "1C-Public:  $SUBNET_1C_PUBLIC"
	echo "1C-Private: $SUBNET_1C_PRIVATE"
	echo "1D-Public:  $SUBNET_1D_PUBLIC"
	echo "1D-Private: $SUBNET_1D_PRIVATE"
	echo "1A-Public:  $SUBNET_1A_PUBLIC"
	echo "1A-Private: $SUBNET_1A_PRIVATE"
}

internet_gateway() {
	INTERNET_GATEWAY=$(aws ec2 create-internet-gateway --query 'InternetGateway.InternetGatewayId' --output text)
	aws ec2 create-tags --resource $INTERNET_GATEWAY --tags 'Key=Name,Value='$VPC_NAME
	aws ec2 attach-internet-gateway --vpc-id $VPC_ID --internet-gateway-id $INTERNET_GATEWAY
	aws ec2 create-route --route-table-id $RTB_PUBLIC --gateway-id $INTERNET_GATEWAY --destination-cidr-block 0.0.0.0/0
}

route_tables() {
	RTB_PRIVATE=$(aws ec2 create-route-table --vpc-id $VPC_ID --query 'RouteTable.RouteTableId' --output text)
	echo "Public RouteTableID: $RTB_PRIVATE"
	aws ec2 create-tags --resource $RTB_PRIVATE --tags 'Key=Name,Value=Private'

	aws ec2 associate-route-table --route-table-id $RTB_PRIVATE --subnet-id $SUBNET_1C_PRIVATE
	aws ec2 associate-route-table --route-table-id $RTB_PRIVATE --subnet-id $SUBNET_1D_PRIVATE
	aws ec2 associate-route-table --route-table-id $RTB_PRIVATE --subnet-id $SUBNET_1A_PRIVATE

	aws ec2 associate-route-table --route-table-id $RTB_PUBLIC --subnet-id $SUBNET_1C_PUBLIC
	aws ec2 associate-route-table --route-table-id $RTB_PUBLIC --subnet-id $SUBNET_1D_PUBLIC
	aws ec2 associate-route-table --route-table-id $RTB_PUBLIC --subnet-id $SUBNET_1A_PUBLIC
}

setup_dns() {
	aws route53 create-hosted-zone \
	  --vpc "VPCRegion=ap-northeast-1,VPCId=$VPC_ID" \
	  --caller-reference "$(date '+%Y-%m-%dT%H:%M:%S')" \
	  --hosted-zone-config 'PrivateZone=true' \
	  --name $VPC_DOMAIN_NAME

	aws route53 create-hosted-zone \
	  --vpc "VPCRegion=ap-northeast-1,VPCId=$VPC_ID" \
	  --caller-reference "$(date '+%Y-%m-%dT%H:%M:%S')" \
	  --hosted-zone-config 'PrivateZone=true' \
	  --name $VPC_REV

	VPC_DHCP_OPTIONS=$( aws ec2 create-dhcp-options \
	  --dhcp-configuration \
	  "Key=domain-name,Values=$VPC_DOMAIN_NAME" \
	  "Key=domain-name-servers,Values=AmazonProvidedDNS" \
	  --output text --query 'DhcpOptions.DhcpOptionsId' )
	echo "VPC_DHCP_OPTIONS: $VPC_DHCP_OPTIONS"

	aws ec2 create-tags \
	  --resources $VPC_DHCP_OPTIONS \
	  --tags "Key=Name,Value=$VPC_DOMAIN_NAME"

	aws ec2 associate-dhcp-options \
	  --vpc-id $VPC_ID --dhcp-options-id $VPC_DHCP_OPTIONS

	aws ec2 modify-vpc-attribute --vpc-id $VPC_ID --enable-dns-hostnames
	aws ec2 modify-vpc-attribute --vpc-id $VPC_ID --enable-dns-support
}

ec2_security_group() {
	GID_NAT_INSTANCE=$( aws ec2 create-security-group \
		--vpc-id $VPC_ID --group-name "NATInstance" --description "NATInstance" \
		--query 'GroupId' --output text)
	echo "GID_NAT_INSTANCE: $GID_NAT_INSTANCE"

	aws ec2 create-tags --resources $GID_NAT_INSTANCE --tags 'Key=Name,Value=NATInstance'
	MY_PUBLIC_IPADDR=$(curl -s httpbin.org/ip | jq -r .origin | perl -E '@c=split(/,/,<>); say $c[0]')
	echo "MY_PUBLIC_IPADDR: $MY_PUBLIC_IPADDR"

	aws ec2 authorize-security-group-ingress --group-id $GID_NAT_INSTANCE \
	--ip-permissions IpProtocol=tcp,FromPort=22,ToPort=22,IpRanges="[{CidrIp=$MY_PUBLIC_IPADDR/32,Description='admin SSH'}]"

	GID_PRIVATE=$( aws ec2 create-security-group \
		--vpc-id $VPC_ID --group-name "Private" --description "Private" \
		--query 'GroupId' --output text)
	echo "GID_PRIVATE: $GID_PRIVATE"
	aws ec2 create-tags --resources $GID_PRIVATE --tags 'Key=Name,Value=Private'

	aws ec2 authorize-security-group-ingress --group-id $GID_PRIVATE \
	--ip-permissions IpProtocol=-1,IpRanges="[{CidrIp=$VPC_SUBNET}]"

	aws ec2 authorize-security-group-ingress --group-id $GID_NAT_INSTANCE \
	--ip-permissions IpProtocol=-1,UserIdGroupPairs="[{GroupId=$GID_PRIVATE,Description=Private}]"
}

ec2_eip_allocation() {
	EC2_ALLOCATION=$( aws ec2 allocate-address --query 'AllocationId' --output text )
	echo "EC2_ALLOCATION: $EC2_ALLOCATION"
	aws ec2 create-tags --resource $EC2_ALLOCATION --tags 'Key=Name,Value=Gateway'
}

ec2_instance() {
	EC2_INSTANCE=$( aws ec2 run-instances \
	  --image-id           $EC2_IMAGE_ID \
	  --instance-type      t2.micro \
	  --key-name           $EC2_KEY \
	  --security-group-ids $GID_NAT_INSTANCE \
	  --subnet-id          $SUBNET_1C_PUBLIC \
	  --private-ip-address $EC2_PRIVATE_IP \
	  --associate-public-ip-address \
	  --output text --query 'Instances[].InstanceId' )

	aws ec2 create-tags --resources $EC2_INSTANCE --tags "Key=Name,Value=gateway"

	./aws-boto3-helper.sh ec2-wait-instance-state $EC2_INSTANCE running

	aws ec2 modify-instance-attribute --instance-id $EC2_INSTANCE --no-source-dest-check
	aws ec2 associate-address --instance-id $EC2_INSTANCE --allocation-id $EC2_ALLOCATION

	./aws-boto3-helper.sh r53-private-zone-update \
		-z $VPC_DOMAIN_NAME \
		-r $VPC_REV \
		-o gateway.$VPC_DOMAIN_NAME \
		-i $EC2_PRIVATE_IP

	EC2_PUBLIC_IP=$(aws ec2 describe-addresses --allocation-ids $EC2_ALLOCATION --query 'Addresses[].PublicIp' --output text)
	echo "EC2_PUBLIC_IP: $EC2_PUBLIC_IP"

}

ec2_setup_ubuntu() {
	ssh ubuntu@$EC2_PUBLIC_IP sudo bash -xeu << 'END_OF_SNIPPET'

NEW_HOSTNAME="gateway"

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get -y install tzdata git-core curl wget vim ntp postfix

rm /etc/localtime
ln -s /usr/share/zoneinfo/Asia/Tokyo /etc/localtime
echo 'Asia/Tokyo' > /etc/timezone
date

cat > /etc/vim/vimrc.local << 'EOS'
syntax on
set wildmenu
set history=100
set number
set scrolloff=5
set autowrite
set tabstop=4
set shiftwidth=4
set softtabstop=0
set termencoding=utf-8
set encoding=utf-8
set fileencodings=utf-8,cp932,euc-jp,iso-2022-jp,ucs2le,ucs-2
set fenc=utf-8
set enc=utf-8
EOS
sudo sh -c "update-alternatives --set editor /usr/bin/vim.basic"

mv /etc/ntp.conf /etc/ntp.conf.orig

cat > /etc/ntp.conf << 'EOS'
driftfile /var/lib/ntp/drift
statistics loopstats peerstats clockstats
filegen loopstats file loopstats type day enable
filegen peerstats file peerstats type day enable
filegen clockstats file clockstats type day enable

restrict -4 default kod notrap nomodify nopeer noquery
restrict -6 default kod nomodify notrap nopeer noquery
restrict 127.0.0.1 
restrict ::1

server 0.amazon.pool.ntp.org iburst
server 1.amazon.pool.ntp.org iburst
server 2.amazon.pool.ntp.org iburst
server 3.amazon.pool.ntp.org iburst
EOS

service ntp restart
sleep 10
ntpq -p

sed -i.bak -e 's/^\(inet_protocols = all\)/#\1/' /etc/postfix/main.cf
echo 'inet_protocols = ipv4' >> /etc/postfix/main.cf
service postfix restart

echo "$NEW_HOSTNAME" > /etc/hostname
echo "127.0.0.1 localhost $NEW_HOSTNAME" > /tmp/hosts
sed -e '1d' /etc/hosts >> /tmp/hosts
cat /tmp/hosts > /etc/hosts
rm /tmp/hosts

END_OF_SNIPPET
	ssh ubuntu@$EC2_PUBLIC_IP sudo reboot || true

	echo -n "再起動待機."
	while ! ssh -o 'ConnectTimeout=1' ubuntu@$EC2_PUBLIC_IP true > /dev/null 2>&1; do
		sleep 1
		echo -n "."
	done
	echo ""

}

ec2_ssh_try_connect() {
	echo "SSH接続試行中"
	while ! ssh -o 'ConnectTimeout=1' ubuntu@$EC2_PUBLIC_IP true; do
		sleep 1
	done
	echo ""
}

ec2_install() {
	tar zcC assets . | ssh ubuntu@$EC2_PUBLIC_IP sudo tar zxvC /
	ssh ubuntu@$EC2_PUBLIC_IP sudo bash -eu << 'END_OF_SNIPPET'
chmod 755 /usr/local/router/router.sh
systemctl list-unit-files --type=service | grep router
sudo systemctl enable router
sudo systemctl start router
systemctl status router || true
journalctl -u router || true
END_OF_SNIPPET
}

ec2_default_gateway() {
	aws ec2 create-route --route-table-id "$RTB_PRIVATE" --instance-id "$EC2_INSTANCE" --destination-cidr-block 0.0.0.0/0
}

check_account_id

# ** VPC **
disp_default_vpc
create_vpc
create_subnets
internet_gateway
route_tables
setup_dns
save_vars
 
# ** NATInstance(gateway) **
ec2_security_group
ec2_eip_allocation
ec2_instance
save_vars

# ** NATInstance(gateway) setup **
ec2_ssh_try_connect
echo "30秒くら待つ"
sleep 30
ec2_setup_ubuntu
ec2_install
ec2_default_gateway
save_vars

