.PHONY: fmt
fmt:
	black .
	ruff check --fix .
	mypy .

.PHONY: lint
lint:
	black --check .
	ruff check .
	mypy .
