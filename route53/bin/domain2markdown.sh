#!/bin/bash
set -eu
REGION=

echo "ドメイン名 | ID | 種類"
echo "---|---|---"


for i in $( bin/cli53 list --format json | jq -r '.[] | "DOMAIN_NAME=\"" + .Name + "\";ID=\"" + .Id + "\";PRIVATE=\"" + (.Config.PrivateZone|tostring) + "\""' ); do
	eval "$i"
	case $PRIVATE in
		"true") PRIVATE="プライベート";;
		"false") PRIVATE="パブリック";;
	esac
	echo "${DOMAIN_NAME%%.} | [${ID#/hostedzone/}](https://console.aws.amazon.com/route53/home#resource-record-sets:${ID#/hostedzone/}) | $PRIVATE"
done

