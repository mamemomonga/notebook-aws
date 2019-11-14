# VPC プライベート・パブリック構成

* このツールはAWS構築の初回のみ使用します。一般用途ではありあせん
* PrivateとPublicを分離したVPC構成を構築します
* EC2にGatewayサーバを構築します
* awscli, jq, curl, bash, docker, ssh その他もろもろ必要です

# 事前準備

[IAM](https://console.aws.amazon.com/iam/home) のページより、アクセスキーを作成する

	$ aws configure --profile theWorld
	AWS Access Key ID [None]: AKIAXXXXXXXXXXXXXXXX
	AWS Secret Access Key [None]: aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
	Default region name [None]: ap-northeast-1
	Default output format [None]:

	$ export AWS_DEFAULT_PROFILE=theWorld

* setup.sh を読む
* config を編集する
* EC2にキーペアを作成し、ssh-addしておく
* aws-boto3-helper.sh が起動するか確認する

# 実行する

* ./setup.sh を実行したら**一気に**構築されます。
* 処理中に 「Are you sure you want to continue connecting (yes/no)? 」と聞かれたらyesと回答します。

# 構築に失敗したら

* 追加された VPC, Route53, EC2 インスタンス, ElasticIP, セキュリティーグループを手動で削除する
* setup.sh をコメントアウトしながら試すか、 var ファイルを消して最初からやる
* ~/.ssh/known-hostsから失敗したキーを削除する

# EC2インスタンス

## 作成時の注意点

AWSコンソールからEC2インスタンスを作成する場合、以下の内容を、都度設定する必要があります。

## Publicインスタンスの場合

* VPCがデフォルトではないので、手動で選択する
* サブネットで \*-Public を選択する。\* は設置したいアビリティーゾーン
* 「自動割り当てパブリックIP」を有効にする

## Privateインスタンスの場合

* VPCがデフォルトではないので、手動で選択する
* サブネットで \*-Private を選択する。\* は設置したいアビリティーゾーン
* セキュリティーグループは「Private」を選択する

## SSH接続

* 事前にSSH秘密鍵をssh-addしておきます。
* 秘密鍵はGitHub登録した公開鍵のキーをご使用ください。
* 登録がない場合は再設定しますのでご連絡ください。

Gatewayサーバ

	$ ssh ubuntu@[GatewayサーバのIPアドレス]

Privateネットワークのサーバ

	$ ssh -o "ProxyCommand ssh ubuntu@[GatewayサーバのIPアドレス] -W %h:%p 2> /dev/null" [ユーザ]@[PrivateIP]


