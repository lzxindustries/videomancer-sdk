#!/bin/bash
# Videomancer SDK - Test Runner Script
# Copyright (C) 2025 LZX Industries LLC
# SPDX-License-Identifier: GPL-3.0-only

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
cd "$SCRIPT_DIR/.."

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Videomancer SDK - Test Suite Runner${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Parse arguments
RUN_CPP=true
RUN_PYTHON=true
RUN_SHELL=true
VERBOSE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --cpp-only)
            RUN_PYTHON=false
            RUN_SHELL=false
            shift
            ;;
        --python-only)
            RUN_CPP=false
            RUN_SHELL=false
            shift
            ;;
        --shell-only)
            RUN_CPP=false
            RUN_PYTHON=false
            shift
            ;;
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --cpp-only      Run only C++ tests"
            echo "  --python-only   Run only Python tests"
            echo "  --shell-only    Run only shell script tests"
            echo "  --verbose, -v   Verbose output"
            echo "  --help, -h      Show this help message"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

# Track results
CPP_PASS=0
PYTHON_PASS=0
SHELL_PASS=0
TOTAL_PASS=0
TOTAL_FAIL=0

# Run C++ tests
if [ "$RUN_CPP" = true ]; then
    echo -e "${YELLOW}Running C++ Unit Tests...${NC}"
    echo ""
    
    if [ ! -d "build" ]; then
        echo -e "${BLUE}Building SDK with tests...${NC}"
        ./build_sdk.sh --test
        CPP_RESULT=$?
    else
        cd build
        if [ "$VERBOSE" = true ]; then
            ctest --output-on-failure --verbose
        else
            ctest --output-on-failure
        fi
        CPP_RESULT=$?
        cd ..
    fi
    
    if [ $CPP_RESULT -eq 0 ]; then
        CPP_PASS=1
        echo -e "${GREEN}✓ C++ tests passed${NC}"
    else
        echo -e "${RED}✗ C++ tests failed${NC}"
    fi
    echo ""
fi

# Run Python tests
if [ "$RUN_PYTHON" = true ]; then
    echo -e "${YELLOW}Running Python Tests...${NC}"
    echo ""
    
    PYTHON_FAILED=0
    
    # Check if Python is available
    if ! command -v python3 &> /dev/null; then
        echo -e "${RED}Python 3 not found. Skipping Python tests.${NC}"
        PYTHON_FAILED=1
    else
        # Run each Python test
        for test_file in tests/python/test_*.py; do
            if [ -f "$test_file" ]; then
                echo -e "${BLUE}Running $(basename $test_file)...${NC}"
                if python3 "$test_file"; then
                    echo -e "${GREEN}✓ $(basename $test_file) passed${NC}"
                else
                    echo -e "${RED}✗ $(basename $test_file) failed${NC}"
                    PYTHON_FAILED=1
                fi
                echo ""
            fi
        done
    fi
    
    if [ $PYTHON_FAILED -eq 0 ]; then
        PYTHON_PASS=1
        echo -e "${GREEN}✓ Python tests passed${NC}"
    else
        echo -e "${RED}✗ Some Python tests failed${NC}"
    fi
    echo ""
fi

# Run shell script tests
if [ "$RUN_SHELL" = true ]; then
    echo -e "${YELLOW}Running Shell Script Tests...${NC}"
    echo ""
    
    SHELL_FAILED=0
    
    # Run each shell test
    for test_file in tests/shell/test_*.sh; do
        if [ -f "$test_file" ]; then
            echo -e "${BLUE}Running $(basename $test_file)...${NC}"
            if bash "$test_file"; then
                echo -e "${GREEN}✓ $(basename $test_file) passed${NC}"
            else
                echo -e "${RED}✗ $(basename $test_file) failed${NC}"
                SHELL_FAILED=1
            fi
            echo ""
        fi
    done
    
    if [ $SHELL_FAILED -eq 0 ]; then
        SHELL_PASS=1
        echo -e "${GREEN}✓ Shell tests passed${NC}"
    else
        echo -e "${RED}✗ Some shell tests failed${NC}"
    fi
    echo ""
fi

# Summary
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Test Summary${NC}"
echo -e "${BLUE}========================================${NC}"

if [ "$RUN_CPP" = true ]; then
    if [ $CPP_PASS -eq 1 ]; then
        echo -e "${GREEN}C++ Tests:    PASSED${NC}"
        TOTAL_PASS=$((TOTAL_PASS + 1))
    else
        echo -e "${RED}C++ Tests:    FAILED${NC}"
        TOTAL_FAIL=$((TOTAL_FAIL + 1))
    fi
fi

if [ "$RUN_PYTHON" = true ]; then
    if [ $PYTHON_PASS -eq 1 ]; then
        echo -e "${GREEN}Python Tests: PASSED${NC}"
        TOTAL_PASS=$((TOTAL_PASS + 1))
    else
        echo -e "${RED}Python Tests: FAILED${NC}"
        TOTAL_FAIL=$((TOTAL_FAIL + 1))
    fi
fi

if [ "$RUN_SHELL" = true ]; then
    if [ $SHELL_PASS -eq 1 ]; then
        echo -e "${GREEN}Shell Tests:  PASSED${NC}"
        TOTAL_PASS=$((TOTAL_PASS + 1))
    else
        echo -e "${RED}Shell Tests:  FAILED${NC}"
        TOTAL_FAIL=$((TOTAL_FAIL + 1))
    fi
fi

echo ""
if [ $TOTAL_FAIL -eq 0 ]; then
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}All test suites passed! ($TOTAL_PASS/$TOTAL_PASS)${NC}"
    echo -e "${GREEN}========================================${NC}"
    exit 0
else
    echo -e "${RED}========================================${NC}"
    echo -e "${RED}Some test suites failed! ($TOTAL_PASS/$((TOTAL_PASS + TOTAL_FAIL)))${NC}"
    echo -e "${RED}========================================${NC}"
    exit 1
fi
