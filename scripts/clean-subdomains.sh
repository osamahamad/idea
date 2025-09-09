#!/bin/bash

# Clean subdomain file by removing http/https prefixes
# Usage: ./clean-subdomains.sh input-file output-file

INPUT_FILE="${1:-subdomains/all-subdomains.txt}"
OUTPUT_FILE="${2:-subdomains/all-subdomains-cleaned.txt}"

echo "🧹 Cleaning subdomain file..."
echo "   Input: $INPUT_FILE"
echo "   Output: $OUTPUT_FILE"

if [ ! -f "$INPUT_FILE" ]; then
    echo "❌ Input file not found: $INPUT_FILE"
    exit 1
fi

# Clean the subdomains
sed 's|^https\?://||' "$INPUT_FILE" | \
sed 's|/$||' | \
grep -v '^$' | \
sort -u > "$OUTPUT_FILE"

ORIGINAL_COUNT=$(wc -l < "$INPUT_FILE")
CLEANED_COUNT=$(wc -l < "$OUTPUT_FILE")

echo "✅ Cleaning completed!"
echo "   Original: $ORIGINAL_COUNT lines"
echo "   Cleaned: $CLEANED_COUNT unique domains"
echo "   Removed: $((ORIGINAL_COUNT - CLEANED_COUNT)) duplicates/empty lines"

echo ""
echo "🔍 Sample cleaned domains:"
head -5 "$OUTPUT_FILE"

echo ""
echo "💡 Next steps:"
echo "   1. Review the cleaned file: $OUTPUT_FILE"
echo "   2. Replace original: mv $OUTPUT_FILE $INPUT_FILE"
echo "   3. Re-encrypt: ./scripts/encrypt-subdomains.sh $INPUT_FILE"
