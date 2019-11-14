#!/bin/bash
set -euo pipefail

do_create() {
	echo "バケットを作成"
	local bucketfile=$WORKDIR"/bucket.json"
	aws s3api create-bucket \
		--region  ap-northeast-1 \
		--create-bucket-configuration LocationConstraint=$REGION \
		--bucket  $BUCKET \
		--output  json \
		> $bucketfile
	cat $bucketfile
}

do_website() {
	echo "ウェブサイトとして設定"
	local websitefile=$WORKDIR"/website.json"
	cat > $websitefile << EOS
{
	"IndexDocument": { "Suffix": "index.html" }
}
EOS
	aws s3api put-bucket-website \
		--bucket $BUCKET \
		--website-configuration file://$websitefile
}

do_auto_publish() {
	echo "ファイル追加時に自動公開する設定"
	local policyfile=$WORKDIR"/auto_publish.json"
	cat > $policyfile << EOS
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AddPerm",
            "Effect": "Allow",
            "Principal": "*",
            "Action": "s3:GetObject",
            "Resource": "arn:aws:s3:::$BUCKET/*"
        }
    ]
}
EOS
	cat $policyfile
	aws s3api put-bucket-policy \
		--bucket $BUCKET \
		--policy file://$policyfile
}

do_specific_ipaddr() {

	if [ -z "${1:-}" ]; then
		echo "USAGE: BUCKET=$BUCKET $0 specific_ipaddr IPADDR/NETMASK"
		exit 1
	fi

	local ipaddr=$1

	echo "特定のIPアドレスからには許可する"
	local policyfile=$WORKDIR"/specific_ipaddr.json"
	cat > $policyfile << EOS
{
    "Version": "2012-10-17",
    "Id": "1",
    "Statement": [
        {
            "Sid": "",
            "Effect": "Allow",
            "Principal": "*",
            "Action": "s3:GetObject",
            "Resource": "arn:aws:s3:::$BUCKET/*",
            "Condition": {
                "IpAddress": {
                    "aws:SourceIp": "$ipaddr"
                }
            }
        }
    ]
}
EOS
	cat $policyfile
	aws s3api put-bucket-policy \
		--bucket $BUCKET \
		--policy file://$policyfile
}

do_create_account() {
	echo "IAMユーザ新規作成"
	local iam_s3_policy_name="S3-"$BUCKET
	local iam_s3_user_name="S3-"$BUCKET

	local target_s3_arn="arn:aws:iam::$ACCOUNT_ID:policy/$iam_s3_policy_name"

	# ポリシー未定義ならポリシー作成
	if ! aws iam get-policy --policy-arn $target_s3_arn > /dev/null 2>&1; then
		iam_create_policy "$iam_s3_policy_name"
	fi

	# ユーザの存在チェック
	if aws iam get-user --user-name $iam_s3_user_name > /dev/null 2>&1; then
		echo "ユーザ $iam_s3_user_name はすでに存在します"
		exit 1
	fi

	# ユーザ作成
	aws iam create-user --user-name $iam_s3_user_name

	# ポリシーをattach
	aws iam attach-user-policy --user-name $iam_s3_user_name --policy-arn $target_s3_arn

	# アクセスキーの作成
	iam_create_accesskey $iam_s3_user_name
}

iam_create_policy() {
	local iam_s3_policy_name=$1

	echo "IAMポリシー新規作成"
	local iam_policy_file=$WORKDIR"/iam-policy.json"
	cat > $iam_policy_file << EOS
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "s3:ListAllMyBuckets",
            "Resource": "arn:aws:s3:::*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "s3:ListBucket",
                "s3:GetBucketLocation",
                "s3:PutObject",
                "s3:GetObject",
                "s3:DeleteObject"
            ],
            "Resource": "arn:aws:s3:::$BUCKET"
        },
        {
            "Effect": "Allow",
            "Action": [
                "s3:PutObject",
                "s3:GetObject",
                "s3:DeleteObject"
            ],
            "Resource": "arn:aws:s3:::$BUCKET/*"
        }
    ]
}
EOS
	aws iam create-policy \
		--policy-name=$iam_s3_policy_name \
		--policy-document file://$iam_policy_file
}

iam_create_accesskey() {
	local iam_s3_user_name=$1
	echo "IAMアクセスキーの作成"
	local accesskeyfile=$WORKDIR'/iam-accesskey.json'
	aws iam create-access-key --user-name $iam_s3_user_name > $accesskeyfile
	cat $accesskeyfile
}

usage() {
	echo "USAGE:"
	echo "  BUCKET=bucket_name $0 [ COMMAND ]"
	echo "COMMAND:"
	for i in $COMMANDS; do echo "  $i"; done
	exit 1
}

# --------------------------------

COMMANDS="create website auto_publish create_account specific_ipaddr"

if [ -z "${BUCKET:-}" ]; then usage; fi

BASEDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REGION=$( aws configure get region || true )
if [ -z "$REGION" ]; then echo "リージョンが取得できません"; exit 1; fi

ACCOUNT_ID=$(aws sts get-caller-identity --output text --query 'Account')

echo "AWS_DEFAULT_PROFILE: $AWS_DEFAULT_PROFILE"
echo "ACCOUNT_ID: $ACCOUNT_ID"
echo "REGION: $REGION"
echo "BUCKET: $BUCKET"

WORKDIR="data/S3-"$BUCKET
mkdir -p $WORKDIR

if [ -z "${1:-}" ]; then usage; exit 1; fi

for i in $COMMANDS; do
	if [ "$i" == "$1" ]; then
		shift
		echo "CMD: $i"
		"do_"$i $@
		exit 0
	fi
done

usage

