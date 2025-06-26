#!/bin/bash

# Production Deployment Verification Script
# Tests deployed application across different platforms

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default configuration
TIMEOUT=30
RETRIES=3
TEST_URL="https://example.com"

echo -e "${BLUE}🔍 Production Deployment Verification${NC}"
echo "================================================"

# Function to print status
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -u|--url)
            BASE_URL="$2"
            shift 2
            ;;
        -t|--timeout)
            TIMEOUT="$2"
            shift 2
            ;;
        -r|--retries)
            RETRIES="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  -u, --url URL       Base URL to test (required)"
            echo "  -t, --timeout SEC   Request timeout in seconds (default: 30)"
            echo "  -r, --retries NUM   Number of retries (default: 3)"
            echo "  -h, --help          Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Check if URL is provided
if [ -z "$BASE_URL" ]; then
    print_error "Base URL is required. Use -u or --url to specify."
    echo "Example: $0 -u https://your-app.fly.dev"
    exit 1
fi

# Remove trailing slash from URL
BASE_URL=${BASE_URL%/}

print_status "Testing deployment at: $BASE_URL"
print_status "Timeout: ${TIMEOUT}s, Retries: $RETRIES"
echo ""

# Function to make HTTP request with retries
make_request() {
    local url="$1"
    local expected_status="$2"
    local description="$3"
    
    print_status "Testing $description..."
    
    for i in $(seq 1 $RETRIES); do
        if [ $i -gt 1 ]; then
            print_status "Retry $((i-1))/$((RETRIES-1))..."
            sleep 2
        fi
        
        response=$(curl -s -w "HTTPSTATUS:%{http_code}\nTIME:%{time_total}" \
                       --max-time $TIMEOUT \
                       --connect-timeout 10 \
                       "$url" 2>/dev/null || echo "HTTPSTATUS:000\nTIME:0")
        
        status=$(echo "$response" | grep "HTTPSTATUS:" | cut -d: -f2)
        time=$(echo "$response" | grep "TIME:" | cut -d: -f2)
        body=$(echo "$response" | sed '/HTTPSTATUS:/d' | sed '/TIME:/d')
        
        if [ "$status" = "$expected_status" ]; then
            print_success "$description - Status: $status, Time: ${time}s"
            if [ -n "$body" ] && [ "$body" != "null" ]; then
                echo "Response preview: $(echo "$body" | head -c 100)..."
            fi
            return 0
        else
            print_warning "$description - Status: $status (expected: $expected_status)"
        fi
    done
    
    print_error "$description failed after $RETRIES attempts"
    return 1
}

# Function to test JSON endpoint
test_json_endpoint() {
    local url="$1"
    local description="$2"
    
    print_status "Testing $description..."
    
    response=$(curl -s --max-time $TIMEOUT "$url" 2>/dev/null || echo "{}")
    
    if echo "$response" | jq . >/dev/null 2>&1; then
        print_success "$description - Valid JSON response"
        echo "Response: $(echo "$response" | jq -c .)"
        return 0
    else
        print_error "$description - Invalid JSON response"
        echo "Response: $response"
        return 1
    fi
}

# Test suite
TEST_RESULTS=()
TOTAL_TESTS=0
PASSED_TESTS=0

# Test 1: Health Check
TOTAL_TESTS=$((TOTAL_TESTS + 1))
if test_json_endpoint "$BASE_URL/health" "Health Check"; then
    PASSED_TESTS=$((PASSED_TESTS + 1))
    TEST_RESULTS+=("✅ Health Check")
else
    TEST_RESULTS+=("❌ Health Check")
fi
echo ""

# Test 2: Homepage
TOTAL_TESTS=$((TOTAL_TESTS + 1))
if make_request "$BASE_URL/" "200" "Homepage"; then
    PASSED_TESTS=$((PASSED_TESTS + 1))
    TEST_RESULTS+=("✅ Homepage")
else
    TEST_RESULTS+=("❌ Homepage")
fi
echo ""

# Test 3: Metrics Endpoint
TOTAL_TESTS=$((TOTAL_TESTS + 1))
if make_request "$BASE_URL/metrics" "200" "Metrics Endpoint"; then
    PASSED_TESTS=$((PASSED_TESTS + 1))
    TEST_RESULTS+=("✅ Metrics Endpoint")
else
    TEST_RESULTS+=("❌ Metrics Endpoint")
fi
echo ""

# Test 4: 404 Page
TOTAL_TESTS=$((TOTAL_TESTS + 1))
if make_request "$BASE_URL/nonexistent" "404" "404 Error Page"; then
    PASSED_TESTS=$((PASSED_TESTS + 1))
    TEST_RESULTS+=("✅ 404 Error Page")
else
    TEST_RESULTS+=("❌ 404 Error Page")
fi
echo ""

# Test 5: URL Shortening (POST request)
TOTAL_TESTS=$((TOTAL_TESTS + 1))
print_status "Testing URL Shortening API..."
shorten_response=$(curl -s --max-time $TIMEOUT \
                       -X POST \
                       -H "Content-Type: application/json" \
                       -d "{\"url\":\"$TEST_URL\"}" \
                       "$BASE_URL/shorten" 2>/dev/null || echo "{}")

if echo "$shorten_response" | jq -e '.short_url' >/dev/null 2>&1; then
    short_url=$(echo "$shorten_response" | jq -r '.short_url')
    print_success "URL Shortening API - Created: $short_url"
    PASSED_TESTS=$((PASSED_TESTS + 1))
    TEST_RESULTS+=("✅ URL Shortening API")
    
    # Test 6: URL Redirect
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    if [ -n "$short_url" ]; then
        # Extract short code from URL
        short_code=$(echo "$short_url" | sed 's|.*/||')
        redirect_status=$(curl -s -o /dev/null -w "%{http_code}" --max-time $TIMEOUT "$BASE_URL/$short_code" 2>/dev/null || echo "000")
        
        if [ "$redirect_status" = "302" ] || [ "$redirect_status" = "301" ]; then
            print_success "URL Redirect - Status: $redirect_status"
            PASSED_TESTS=$((PASSED_TESTS + 1))
            TEST_RESULTS+=("✅ URL Redirect")
        else
            print_error "URL Redirect - Status: $redirect_status (expected: 301/302)"
            TEST_RESULTS+=("❌ URL Redirect")
        fi
    else
        print_error "URL Redirect - No short URL to test"
        TEST_RESULTS+=("❌ URL Redirect")
    fi
else
    print_error "URL Shortening API - Invalid response"
    TEST_RESULTS+=("❌ URL Shortening API")
    TEST_RESULTS+=("❌ URL Redirect (skipped)")
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
fi
echo ""

# Test 7: Security Headers
TOTAL_TESTS=$((TOTAL_TESTS + 1))
print_status "Testing Security Headers..."
security_headers=$(curl -s -I --max-time $TIMEOUT "$BASE_URL/" 2>/dev/null || echo "")

security_score=0
if echo "$security_headers" | grep -qi "x-content-type-options"; then
    security_score=$((security_score + 1))
fi
if echo "$security_headers" | grep -qi "x-frame-options"; then
    security_score=$((security_score + 1))
fi
if echo "$security_headers" | grep -qi "x-xss-protection"; then
    security_score=$((security_score + 1))
fi

if [ $security_score -ge 2 ]; then
    print_success "Security Headers - $security_score/3 headers present"
    PASSED_TESTS=$((PASSED_TESTS + 1))
    TEST_RESULTS+=("✅ Security Headers")
else
    print_warning "Security Headers - Only $security_score/3 headers present"
    TEST_RESULTS+=("⚠️  Security Headers")
fi
echo ""

# Test 8: Performance Check
TOTAL_TESTS=$((TOTAL_TESTS + 1))
print_status "Testing Performance..."
perf_time=$(curl -s -w "%{time_total}" -o /dev/null --max-time $TIMEOUT "$BASE_URL/" 2>/dev/null || echo "999")

if (( $(echo "$perf_time < 2.0" | bc -l) )); then
    print_success "Performance - Response time: ${perf_time}s (< 2s)"
    PASSED_TESTS=$((PASSED_TESTS + 1))
    TEST_RESULTS+=("✅ Performance")
elif (( $(echo "$perf_time < 5.0" | bc -l) )); then
    print_warning "Performance - Response time: ${perf_time}s (acceptable)"
    PASSED_TESTS=$((PASSED_TESTS + 1))
    TEST_RESULTS+=("⚠️  Performance")
else
    print_error "Performance - Response time: ${perf_time}s (> 5s)"
    TEST_RESULTS+=("❌ Performance")
fi
echo ""

# Summary
echo "================================================"
echo -e "${BLUE}📊 Test Results Summary${NC}"
echo "================================================"

for result in "${TEST_RESULTS[@]}"; do
    echo "$result"
done

echo ""
echo "Total Tests: $TOTAL_TESTS"
echo "Passed: $PASSED_TESTS"
echo "Failed: $((TOTAL_TESTS - PASSED_TESTS))"
echo "Success Rate: $(( PASSED_TESTS * 100 / TOTAL_TESTS ))%"
echo ""

if [ $PASSED_TESTS -eq $TOTAL_TESTS ]; then
    echo -e "${GREEN}🎉 All tests passed! Deployment is healthy.${NC}"
    exit 0
elif [ $PASSED_TESTS -ge $((TOTAL_TESTS * 3 / 4)) ]; then
    echo -e "${YELLOW}⚠️  Most tests passed. Deployment is functional but may need attention.${NC}"
    exit 0
else
    echo -e "${RED}❌ Multiple tests failed. Deployment may have issues.${NC}"
    exit 1
fi