#!/bin/bash

# Decrypt and analyze Nuclei scan results
# Usage: ./decrypt-results.sh [results-directory] [output-directory]

set -e

RESULTS_DIR="${1:-./encrypted-results}"
OUTPUT_DIR="${2:-./decrypted-results}"

echo "🔓 Nuclei Results Decryption Tool"
echo "================================="

# Check if GPG is available
if ! command -v gpg &> /dev/null; then
    echo "❌ GPG is not installed. Please install it first."
    exit 1
fi

# Check if results directory exists
if [ ! -d "$RESULTS_DIR" ]; then
    echo "❌ Results directory not found: $RESULTS_DIR"
    echo "   Please download the encrypted artifacts from GitHub Actions first."
    exit 1
fi

# Create output directory
mkdir -p "$OUTPUT_DIR"

echo "📁 Processing encrypted files from: $RESULTS_DIR"
echo "📁 Decrypted files will be saved to: $OUTPUT_DIR"
echo ""

# Find all GPG encrypted files
ENCRYPTED_FILES=($(find "$RESULTS_DIR" -name "*.gpg" -type f))

if [ ${#ENCRYPTED_FILES[@]} -eq 0 ]; then
    echo "❌ No encrypted files (.gpg) found in $RESULTS_DIR"
    exit 1
fi

echo "🔍 Found ${#ENCRYPTED_FILES[@]} encrypted files"
echo ""

# Decrypt each file
DECRYPTED_COUNT=0
FAILED_COUNT=0

for encrypted_file in "${ENCRYPTED_FILES[@]}"; do
    filename=$(basename "$encrypted_file" .gpg)
    output_file="$OUTPUT_DIR/$filename"
    
    echo "🔓 Decrypting: $(basename "$encrypted_file")"
    
    if gpg --batch --yes --quiet --decrypt "$encrypted_file" > "$output_file" 2>/dev/null; then
        echo "   ✅ Decrypted: $filename"
        DECRYPTED_COUNT=$((DECRYPTED_COUNT + 1))
    else
        echo "   ❌ Failed to decrypt: $(basename "$encrypted_file")"
        FAILED_COUNT=$((FAILED_COUNT + 1))
        rm -f "$output_file"
    fi
done

echo ""
echo "📊 Decryption Summary:"
echo "   ✅ Successfully decrypted: $DECRYPTED_COUNT files"
echo "   ❌ Failed to decrypt: $FAILED_COUNT files"
echo ""

# Analyze decrypted results if any exist
if [ $DECRYPTED_COUNT -gt 0 ]; then
    echo "📈 Analyzing results..."
    
    # Find JSON result files
    JSON_FILES=($(find "$OUTPUT_DIR" -name "*.json" -type f | grep -E "(nuclei_results|consolidated_report)" | head -10))
    
    if [ ${#JSON_FILES[@]} -gt 0 ]; then
        echo ""
        echo "🎯 Quick Analysis:"
        
        TOTAL_FINDINGS=0
        CRITICAL=0
        HIGH=0
        MEDIUM=0
        LOW=0
        INFO=0
        
        for json_file in "${JSON_FILES[@]}"; do
            if [ -s "$json_file" ]; then
                # Check if it's a consolidated report
                if grep -q '"overall_summary"' "$json_file" 2>/dev/null; then
                    echo "📋 Consolidated Report: $(basename "$json_file")"
                    
                    TOTAL_FINDINGS=$(jq -r '.overall_summary.total_findings // 0' "$json_file" 2>/dev/null || echo "0")
                    CRITICAL=$(jq -r '.overall_summary.critical // 0' "$json_file" 2>/dev/null || echo "0")
                    HIGH=$(jq -r '.overall_summary.high // 0' "$json_file" 2>/dev/null || echo "0")
                    MEDIUM=$(jq -r '.overall_summary.medium // 0' "$json_file" 2>/dev/null || echo "0")
                    LOW=$(jq -r '.overall_summary.low // 0' "$json_file" 2>/dev/null || echo "0")
                    INFO=$(jq -r '.overall_summary.info // 0' "$json_file" 2>/dev/null || echo "0")
                    SUBDOMAINS=$(jq -r '.overall_summary.total_subdomains_scanned // 0' "$json_file" 2>/dev/null || echo "0")
                    
                    echo "   🎯 Total Findings: $TOTAL_FINDINGS"
                    echo "   📊 Subdomains Scanned: $SUBDOMAINS"
                    echo "   🚨 Critical: $CRITICAL | High: $HIGH | Medium: $MEDIUM | Low: $LOW | Info: $INFO"
                    
                elif [ "$(jq -r 'type' "$json_file" 2>/dev/null)" = "array" ] || grep -q '"info":' "$json_file" 2>/dev/null; then
                    # Individual batch results
                    BATCH_FINDINGS=$(jq -s 'length' "$json_file" 2>/dev/null || echo "0")
                    if [ "$BATCH_FINDINGS" -gt 0 ]; then
                        echo "📄 Batch Results: $(basename "$json_file") - $BATCH_FINDINGS findings"
                    fi
                fi
            fi
        done
        
        echo ""
        echo "🔍 Available decrypted files:"
        ls -la "$OUTPUT_DIR"
        
        echo ""
        echo "💡 Analysis Tips:"
        echo "   • Use 'jq' to parse JSON results: jq '.[] | select(.info.severity==\"critical\")' results.json"
        echo "   • Filter by template: jq '.[] | select(.\"template-id\"==\"CVE-2021-44228\")' results.json"
        echo "   • Count by host: jq -r '.host' results.json | sort | uniq -c | sort -nr"
        echo "   • Export to CSV: jq -r '[.host, .\"template-id\", .info.severity, .info.name] | @csv' results.json"
        
    else
        echo "ℹ️  No JSON result files found for analysis"
    fi
else
    echo "❌ No files were successfully decrypted"
    echo ""
    echo "🔧 Troubleshooting:"
    echo "   • Make sure you have the correct GPG private key imported"
    echo "   • Check if the key has expired: gpg --list-keys"
    echo "   • Import your private key: gpg --import private-key.asc"
fi

echo ""
echo "✅ Decryption process completed!"
echo "📁 Decrypted files location: $OUTPUT_DIR"
