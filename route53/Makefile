ACCOUNT_ID=123456789012

default: ready
	@echo "USAGE:"
	@echo "  make cli53のダウンロード"
	@echo "  make export ゾーンファイルのエクスポート"

bin/cli53:
	bin/get-cli53.sh

check_account_id:
	@if [ "$$( aws sts get-caller-identity --query 'Account' --output text )" != "$(ACCOUNT_ID)" ]; then echo "AccountIDが合致しません"; exit 1; fi
	@echo "AccountIDは正常です $(ACCOUNT_ID)"

ready: bin/cli53 check_account_id

export: ready
	mkdir -p domains
	@for i in $$( bin/cli53 list --format json | jq -r '.[].Name' ); do \
		echo "Export [$${i%.}]"; \
		bin/cli53 export --full $${i%.} > domains/$$i"txt"; \
	done

markdown: ready
	echo "# Route53情報" > README.md
	echo "" >> README.md
	./domain2markdown.sh >> README.md
	echo "" >> README.md
	echo "[ツールの利用方法](./Usage.md)" >> README.md

.PHONY: default check_account_id ready export
