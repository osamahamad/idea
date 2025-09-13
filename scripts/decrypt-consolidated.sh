#!/bin/bash

# Decrypt consolidated Nuclei scan results
# Usage: ./decrypt-consolidated.sh [scan-results-branch]

set -e

BRANCH="${1:-scan-results}"
OUTPUT_DIR="decrypted-consolidated"

echo "🔓 Decrypting Consolidated Nuclei Results"
echo "========================================"

# Check if GPG is available
if ! command -v gpg &> /dev/null; then
    echo "❌ GPG is not installed. Please install it first."
    exit 1
fi

# Clone or update the results branch
if [ -d "scan-results" ]; then
    echo "📁 Updating existing scan-results directory..."
    cd scan-results
    git pull origin $BRANCH
    cd ..
else
    echo "📁 Cloning scan-results branch..."
    git clone -b $BRANCH https://github.com/osamahamad/idea.git scan-results
fi

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Check if consolidated files exist
if [ ! -f "scan-results/output/all_latest_nuclei_results.json.gpg" ]; then
    echo "❌ Consolidated JSON file not found in scan-results/output/"
    echo "Available files:"
    ls -la scan-results/output/ || echo "No output directory found"
    exit 1
fi

if [ ! -f "scan-results/output/all_latest_nuclei_results.txt.gpg" ]; then
    echo "❌ Consolidated text file not found in scan-results/output/"
    exit 1
fi

echo "✅ Found consolidated files"

# Decrypt JSON results
echo "🔓 Decrypting JSON results..."
if gpg --decrypt scan-results/output/all_latest_nuclei_results.json.gpg > "$OUTPUT_DIR/all_nuclei_results.json" 2>/dev/null; then
    echo "✅ JSON results decrypted: $OUTPUT_DIR/all_nuclei_results.json"
    
    # Show summary
    TOTAL=$(jq 'length' "$OUTPUT_DIR/all_nuclei_results.json" 2>/dev/null || echo "0")
    CRITICAL=$(jq '[.[] | select(.info.severity == "critical")] | length' "$OUTPUT_DIR/all_nuclei_results.json" 2>/dev/null || echo "0")
    HIGH=$(jq '[.[] | select(.info.severity == "high")] | length' "$OUTPUT_DIR/all_nuclei_results.json" 2>/dev/null || echo "0")
    MEDIUM=$(jq '[.[] | select(.info.severity == "medium")] | length' "$OUTPUT_DIR/all_nuclei_results.json" 2>/dev/null || echo "0")
    LOW=$(jq '[.[] | select(.info.severity == "low")] | length' "$OUTPUT_DIR/all_nuclei_results.json" 2>/dev/null || echo "0")
    INFO=$(jq '[.[] | select(.info.severity == "info")] | length' "$OUTPUT_DIR/all_nuclei_results.json" 2>/dev/null || echo "0")
    
    echo "📊 JSON Summary:"
    echo "   Total Findings: $TOTAL"
    echo "   Critical: $CRITICAL"
    echo "   High: $HIGH"
    echo "   Medium: $MEDIUM"
    echo "   Low: $LOW"
    echo "   Info: $INFO"
else
    echo "❌ Failed to decrypt JSON results"
fi

# Decrypt text results
echo "🔓 Decrypting text results..."
if gpg --decrypt scan-results/output/all_latest_nuclei_results.txt.gpg > "$OUTPUT_DIR/all_nuclei_results.txt" 2>/dev/null; then
    echo "✅ Text results decrypted: $OUTPUT_DIR/all_nuclei_results.txt"
    
    # Show text summary
    LINES=$(wc -l < "$OUTPUT_DIR/all_nuclei_results.txt" 2>/dev/null || echo "0")
    echo "📊 Text Summary:"
    echo "   Total Lines: $LINES"
else
    echo "❌ Failed to decrypt text results"
fi

echo ""
echo "🎯 Consolidated Results Ready!"
echo "=============================="
echo "📁 Output directory: $OUTPUT_DIR/"
echo "📄 JSON file: $OUTPUT_DIR/all_nuclei_results.json"
echo "📄 Text file: $OUTPUT_DIR/all_nuclei_results.txt"
echo ""
echo "🔍 Quick analysis commands:"
echo "   # View first 10 findings"
echo "   head -10 $OUTPUT_DIR/all_nuclei_results.txt"
echo ""
echo "   # Count by severity"
echo "   jq -r '.info.severity' $OUTPUT_DIR/all_nuclei_results.json | sort | uniq -c"
echo ""
echo "   # Get unique hosts"
echo "   jq -r '.host' $OUTPUT_DIR/all_nuclei_results.json | sort | uniq"
echo ""
echo "   # Export to CSV"
echo "   jq -r '[.host, .info.name, .info.severity, .info.description] | @csv' $OUTPUT_DIR/all_nuclei_results.json > $OUTPUT_DIR/results.csv"
echo ""
echo "✅ All consolidated results decrypted and ready for analysis!"
