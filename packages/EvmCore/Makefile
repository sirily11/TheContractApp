.PHONY: e2e-network e2e-test e2e-test-stop lint generate-routes

build:
	@echo "Building EvmCore..."
	@swift build

e2e-network:
	@echo "Starting Anvil network..."
	pkill -f "anvil" || true
	anvil &
	@echo "Waiting for Anvil to be ready..."
	@sleep 2

test: e2e-network
	@echo "Running tests..."
	@swift test

fmt:
	@echo "Formatting code..."
	@swift format

lint:
	@echo "Running swiftformat..."
	@swiftformat .