lock:
	poetry lock
.PHONY: lock

install:
	poetry install
.PHONY: install

lint:
	autoflake --check -i -r --remove-all-unused-imports .
	isort --check --atomic .
	black --check .
	mypy .
.PHONY: lint

fmt:
	autoflake -i -r --remove-all-unused-imports .
	isort --atomic .
	black .
	mypy .
.PHONY: fmt
