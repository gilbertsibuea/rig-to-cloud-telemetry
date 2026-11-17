.PHONY: init infra-up infra-down run-sim run-edge run-cloud run-dashboard test

PYTHON ?= python3
VENV ?= simulator/.venv
PIP := $(VENV)/bin/pip
PY := $(VENV)/bin/python
SERIAL_PORT_FILE := $(CURDIR)/.serial_port

init:
	@echo "==> Go workspace modules"
	cd shared && go mod tidy
	cd edge-daemon && go mod tidy
	cd cloud-backend && go mod tidy
	@echo "==> Python simulator venv"
	$(PYTHON) -m venv $(VENV)
	$(PIP) install --upgrade pip
	$(PIP) install -r simulator/requirements.txt
	@echo "==> Dashboard (Node)"
	cd dashboard && npm install
	@echo "==> Init complete"

# IDE terminals often lack the docker group until Cursor/IDE restart.
infra-up:
	@if docker info >/dev/null 2>&1; then \
		docker compose up -d; \
	else \
		sg docker -c 'docker compose up -d'; \
	fi

infra-down:
	@if docker info >/dev/null 2>&1; then \
		docker compose down; \
	else \
		sg docker -c 'docker compose down'; \
	fi

run-sim:
	cd simulator && $(CURDIR)/$(VENV)/bin/python wits_generator.py

run-edge:
	@if [ -z "$$SERIAL_PORT" ] && [ -f "$(SERIAL_PORT_FILE)" ]; then \
		export SERIAL_PORT=$$(tr -d '\n' < "$(SERIAL_PORT_FILE)"); \
		echo "Using SERIAL_PORT=$$SERIAL_PORT from .serial_port"; \
		cd edge-daemon && SERIAL_PORT=$$SERIAL_PORT go run ./cmd/daemon; \
	elif [ -n "$$SERIAL_PORT" ]; then \
		cd edge-daemon && go run ./cmd/daemon; \
	else \
		echo "SERIAL_PORT missing. Start simulator first: make run-sim"; \
		exit 1; \
	fi

run-cloud:
	cd cloud-backend && go run ./cmd/ingest

run-dashboard:
	cd dashboard && npm run dev

test:
	cd shared && go test ./...
	cd edge-daemon && go test ./...
	cd cloud-backend && go test ./...
