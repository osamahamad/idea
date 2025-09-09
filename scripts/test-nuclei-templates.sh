#!/bin/bash

# Test Nuclei template detection and installation
# This helps debug template issues before running on GitHub Actions

set -e

echo "🧪 Testing Nuclei Template Setup"
echo "================================"

# Check if nuclei is installed
if ! command -v nuclei &> /dev/null; then
    echo "❌ Nuclei is not installed"
    echo "💡 Install with: go install -v github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest"
    exit 1
fi

echo "🔍 Current Nuclei version:"
nuclei -version

echo ""
echo "🔄 Updating templates..."
nuclei -update-templates

echo ""
echo "🔍 Checking template locations..."
for template_dir in ~/nuclei-templates ~/.nuclei-templates; do
    if [ -d "$template_dir" ]; then
        TEMPLATE_COUNT=$(find "$template_dir" -name "*.yaml" -o -name "*.yml" 2>/dev/null | wc -l)
        echo "📁 Found $TEMPLATE_COUNT templates at: $template_dir"
        ls -la "$template_dir" | head -5
        
        # Check specific directories
        for subdir in cves vulnerabilities exposures; do
            if [ -d "$template_dir/$subdir" ]; then
                SUBDIR_COUNT=$(find "$template_dir/$subdir" -name "*.yaml" -o -name "*.yml" 2>/dev/null | wc -l)
                echo "   📂 $subdir/: $SUBDIR_COUNT templates"
            else
                echo "   ❌ $subdir/: Not found"
            fi
        done
        
        NUCLEI_TEMPLATES_PATH="$template_dir"
        break
    else
        echo "❌ $template_dir: Not found"
    fi
done

if [ -z "${NUCLEI_TEMPLATES_PATH:-}" ]; then
    echo "⚠️ No template directory found!"
    exit 1
fi

echo ""
echo "🧪 Testing template usage..."

# Create test target
TEST_TARGET="httpbin.org"
echo "$TEST_TARGET" > test-target.txt

# Test different template configurations
echo "🔍 Testing full template scan (first 5 templates only)..."
nuclei -l test-target.txt -t "$NUCLEI_TEMPLATES_PATH/" -silent -j -o test-results-full.json -timeout 5 -retries 1 -stats -max-templates 5

echo "🔍 Testing CVE templates..."
if [ -d "$NUCLEI_TEMPLATES_PATH/cves" ]; then
    nuclei -l test-target.txt -t "$NUCLEI_TEMPLATES_PATH/cves/" -silent -j -o test-results-cves.json -timeout 5 -retries 1 -stats -max-templates 5
else
    echo "⚠️ CVE templates directory not found"
fi

echo ""
echo "📊 Test Results:"
if [ -f "test-results-full.json" ]; then
    FULL_RESULTS=$(wc -l < test-results-full.json 2>/dev/null || echo "0")
    echo "   Full scan: $FULL_RESULTS findings"
    if [ "$FULL_RESULTS" -gt 0 ]; then
        echo "   Sample finding:"
        head -1 test-results-full.json | jq -r '"\(.template_id): \(.info.name)"' 2>/dev/null || head -1 test-results-full.json
    fi
else
    echo "   ❌ Full scan: No results file generated"
fi

if [ -f "test-results-cves.json" ]; then
    CVE_RESULTS=$(wc -l < test-results-cves.json 2>/dev/null || echo "0")
    echo "   CVE scan: $CVE_RESULTS findings"
else
    echo "   ❌ CVE scan: No results file generated"
fi

# Cleanup
rm -f test-target.txt test-results-*.json

echo ""
echo "✅ Template test completed!"
echo "📁 Templates location: $NUCLEI_TEMPLATES_PATH"
echo "📊 Total templates: $(find "$NUCLEI_TEMPLATES_PATH" -name "*.yaml" -o -name "*.yml" 2>/dev/null | wc -l)"

echo ""
echo "💡 For GitHub Actions, use:"
echo "   TEMPLATES=\"-t $NUCLEI_TEMPLATES_PATH/\""
echo "   or for specific categories:"
echo "   TEMPLATES=\"-t $NUCLEI_TEMPLATES_PATH/cves/ -t $NUCLEI_TEMPLATES_PATH/vulnerabilities/\""
