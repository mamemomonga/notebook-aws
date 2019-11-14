ACCOUNT_ID=123456789012

default: ready
	@echo "USAGE:"
	@echo "  make cli53のダウンロード"
	@echo "  make export DNS設定のエクスポート"

bin/cli53:
	bin/get-cli53.sh

check_account_id:
	@if [ "$$( aws sts get-caller-identity --query 'Account' --output text )" != "$(ACCOUNT_ID)" ]; then echo "AccountIDが合致しません"; exit 1; fi
	@echo "AccountIDは正常です $(ACCOUNT_ID)"

ready: bin/cli53 check_account_id

export: ready
	bin/cli53 export --full example.com      > example.com.txt
	bin/cli53 export --full example.aws      > example.aws.txt
	bin/cli53 export --full 32.172.in-addr.arpa > 32.172.in-addr.arpa.txt

.PHONY: default check_account_id ready
