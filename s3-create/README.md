# s3-create

* S3バケットを作ったり、当該バケット専用のユーザを作成します。
* 処理の情報やユーザのアクセスキーなどは、data/S3-[BucketName] のフォルダに保存されます。

使い方

	$ ./s3-create.sh

バケットの作成

	$ BUCKET=media.mamemo.online ./s3-create.sh create

ウェブサイト用として公開設定にする

	$ BUCKET=media.mamemo.online ./s3-create.sh website

ACL未設定でアップロードされても公開されるようにする

	$ BUCKET=media.mamemo.online ./s3-create.sh auto_publish

S3-[BucketName] のユーザとポリシーをIAMに作成し、アクセスキーのペアを取得する

	$ BUCKET=media.mamemo.online ./s3-create.sh create_account

公開先を特定のIPアドレスに限定したバケットにする

	$ BUCKET=media.mamemo.online ./s3-create.sh specific_ipaddr IPADDR/NETMASK



