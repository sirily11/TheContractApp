.PHONY: e2e-network e2e-test e2e-test-stop lint generate-routes coverage coverage-report coverage-html coverage-clean

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
ifeq ($(CI),true)
	@echo "CI environment detected - running tests sequentially..."
	@swift test --parallel=false
else
	@swift test
endif

# Run tests with code coverage enabled
coverage: e2e-network
	@echo "Running tests with code coverage..."
ifeq ($(CI),true)
	@echo "CI environment detected - running tests sequentially..."
	@swift test --enable-code-coverage --parallel=false
else
	@swift test --enable-code-coverage
endif
	@$(MAKE) coverage-report

# Generate coverage report (text format)
coverage-report:
	@echo "Generating coverage report..."
	@xcrun llvm-profdata merge -sparse .build/arm64-apple-macosx/debug/codecov/*.profraw -o .build/coverage.profdata 2>/dev/null || true
	@echo ""
	@echo "=== Coverage Summary ==="
	@xcrun llvm-cov report \
		.build/arm64-apple-macosx/debug/EvmCorePackageTests.xctest/Contents/MacOS/EvmCorePackageTests \
		-instr-profile=.build/coverage.profdata 2>/dev/null | \
		grep -E "(Sources/EvmCore|Sources/BIP39|Sources/Solidity|^TOTAL)" | \
		grep -v ".build/checkouts" || echo "Coverage data not found. Run 'make coverage' first."
	@echo ""

# Generate detailed HTML coverage report
coverage-html: coverage-report
	@echo "Generating HTML coverage report..."
	@xcrun llvm-cov show \
		.build/arm64-apple-macosx/debug/EvmCorePackageTests.xctest/Contents/MacOS/EvmCorePackageTests \
		-instr-profile=.build/coverage.profdata \
		-format=html \
		-output-dir=.build/coverage-html \
		-ignore-filename-regex=".build/checkouts" 2>/dev/null || true
	@echo "HTML coverage report generated at: .build/coverage-html/index.html"
	@open .build/coverage-html/index.html 2>/dev/null || true

# Clean coverage data
coverage-clean:
	@echo "Cleaning coverage data..."
	@rm -rf .build/coverage.profdata .build/coverage-html .build/arm64-apple-macosx/debug/codecov/*.profraw
	@echo "Coverage data cleaned."

fmt:
	@echo "Formatting code..."
	@swift format

lint:
	@echo "Running swiftformat..."
	@swiftformat .