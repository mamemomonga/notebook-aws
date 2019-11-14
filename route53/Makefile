include AccountID

default: markdown export

bin/cli53:
	bin/get-cli53.sh

check_account_id:
	@if [ "$$( aws sts get-caller-identity --query 'Account' --output text )" != "$(ACCOUNT_ID)" ]; then echo "AccountIDが合致しません"; exit 1; fi
	@echo "AccountIDは正常です $(ACCOUNT_ID)"

ready: bin/cli53 check_account_id

markdown: ready
	echo "# Route53情報" > README.md
	echo "" >> README.md
	./domain2markdown.sh >> README.md
	echo "" >> README.md
	echo "[ツールの利用方法](./Usage.md)" >> README.md

.PHONY: default check_account_id ready export
