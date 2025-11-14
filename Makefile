.PHONY: generate-docs lint

generate-docs:
	@if ! command -v terraform-docs >/dev/null 2>&1; then \
		echo "terraform-docs not found, installing..."; \
		go install github.com/terraform-docs/terraform-docs@v0.20.0; \
	fi
	terraform-docs markdown table --output-file README.md --output-mode inject .

lint:
	@if ! command -v tflint >/dev/null 2>&1; then \
		echo "tflint not found, installing..."; \
		brew install tflint; \
	fi
	tflint --init
	tflint