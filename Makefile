# Build directories
BUILD_DIR = build/host
TEST_BUILD_DIR = build/test
STATIC_BUILD_DIR = build/static
COVERAGE_DIR = build/coverage
SAN_DIR = build/sanitizers

# Tools
CMAKE ?= cmake
CTEST ?= ctest
PYTHON ?= python3
CPPCHECK ?= cppcheck
CLANG_FORMAT ?= clang-format
CLANG_TIDY ?= clang-tidy

# Source directories for analysis
SRC_DIRS = kernel hal drivers net power core services systems boards examples

.PHONY: all build test coverage static-analysis dynamic-analysis format clean help

# Default action
all: format static-analysis build test

build:
	@echo "==> Configuring and building the project..."
	$(CMAKE) -B $(BUILD_DIR) -DCMAKE_BUILD_TYPE=Release -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
	$(CMAKE) --build $(BUILD_DIR) --parallel

test:
	@echo "==> Configuring and building tests..."
	$(CMAKE) -B $(TEST_BUILD_DIR) -DEOS_BUILD_TESTS=ON -DEOS_PRODUCT=vbox_test -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
	$(CMAKE) --build $(TEST_BUILD_DIR) --parallel
	@echo "==> Running C unit tests (CTest)..."
	$(CTEST) --test-dir $(TEST_BUILD_DIR) --output-on-failure
	@echo "==> Running functional and integration tests (Pytest)..."
	$(PYTHON) run_all_tests.py

coverage:
	@echo "==> Building with coverage flags..."
	$(CMAKE) -B $(COVERAGE_DIR) -DEOS_BUILD_TESTS=ON -DEOS_PRODUCT=vbox_test -DCMAKE_C_FLAGS="--coverage" -DCMAKE_EXE_LINKER_FLAGS="--coverage"
	$(CMAKE) --build $(COVERAGE_DIR) --parallel
	@echo "==> Running tests for C coverage..."
	$(CTEST) --test-dir $(COVERAGE_DIR) --output-on-failure
	@echo "==> Generating C code coverage HTML report..."
	mkdir -p $(COVERAGE_DIR)/html
	gcovr -r . --html --html-details -o $(COVERAGE_DIR)/html/index.html || echo "Note: gcovr not installed or failed, skipping HTML report."
	@echo "==> Running Python tests coverage..."
	$(PYTHON) run_all_tests.py --tb=short --cov=. --cov-report=xml --cov-report=term-missing --cov-fail-under=0

static-analysis:
	@echo "==> Configuring for static analysis..."
	$(CMAKE) -B $(STATIC_BUILD_DIR) -DCMAKE_BUILD_TYPE=Release -DCMAKE_EXPORT_COMPILE_COMMANDS=ON -DEOS_ENABLE_CPPCHECK=ON
	@echo "==> Running cppcheck via CMake..."
	$(CMAKE) --build $(STATIC_BUILD_DIR) --target cppcheck || echo "Note: some cppcheck issues were found."
	@echo "==> Running clang-tidy..."
	find $(SRC_DIRS) -name '*.c' -exec $(CLANG_TIDY) -p $(STATIC_BUILD_DIR) {} + || echo "Note: some clang-tidy warnings were found."

dynamic-analysis:
	@echo "==> Building with AddressSanitizer (ASan) and UndefinedBehaviorSanitizer (UBSan)..."
	$(CMAKE) -B $(SAN_DIR) -DEOS_BUILD_TESTS=ON -DEOS_PRODUCT=vbox_test \
		-DCMAKE_C_FLAGS="-fsanitize=address,undefined -g -fno-omit-frame-pointer" \
		-DCMAKE_EXE_LINKER_FLAGS="-fsanitize=address,undefined"
	$(CMAKE) --build $(SAN_DIR) --parallel
	@echo "==> Running tests with sanitizers..."
	UBSAN_OPTIONS=print_stacktrace=1 $(CTEST) --test-dir $(SAN_DIR) --output-on-failure

format:
	@echo "==> Formatting C/C++ code with clang-format..."
	@echo "Skipping formatting for now... Will be enabled in the future..."
#	find $(SRC_DIRS) include/ -type f \( -name '*.c' -o -name '*.h' \) -exec $(CLANG_FORMAT) -i {} +

clean:
	@echo "==> Cleaning build directories..."
	rm -rf build/
	rm -f cppcheck.log

help:
	@echo "========================================="
	@echo "  EoS - Build System (Make)"
	@echo "========================================="
	@echo "Available commands:"
	@echo "  make build             - Build the main project (Release)"
	@echo "  make test              - Build and run all tests (C and Python)"
	@echo "  make coverage          - Run tests and generate code coverage reports"
	@echo "  make static-analysis   - Run static analysis (cppcheck & clang-tidy)"
	@echo "  make dynamic-analysis  - Build and run tests with ASan & UBSan"
	@echo "  make format            - Format C/C++ code using .clang-format"
	@echo "  make all               - Run format, static-analysis, build, and test"
	@echo "  make clean             - Remove build directories"
	@echo "  make help              - Show this help menu"
