#!/bin/bash

# Encrypt subdomain files for secure storage in public repository
# Usage: ./encrypt-subdomains.sh [subdomain-file] [--validate]

set -e

SUBDOMAIN_FILE="${1:-subdomains/all-subdomains.txt}"
OUTPUT_FILE="${SUBDOMAIN_FILE}.gpg"

echo "🔐 Encrypting Subdomain File for Public Repository"
echo "================================================="

# Check if input file exists
if [ ! -f "$SUBDOMAIN_FILE" ]; then
    echo "❌ Subdomain file not found: $SUBDOMAIN_FILE"
    echo ""
    echo "📝 Usage:"
    echo "   ./encrypt-subdomains.sh [subdomain-file] [--validate]"
    echo "   --validate: Run detailed subdomain validation (optional, slower for large files)"
    echo ""
    echo "📋 Expected format (one subdomain per line):"
    echo "   example.com"
    echo "   api.example.com"
    echo "   admin.example.com"
    exit 1
fi

# Check if GPG is available
if ! command -v gpg &> /dev/null; then
    echo "❌ GPG is not installed. Please install it first:"
    echo "   - Ubuntu/Debian: sudo apt-get install gnupg"
    echo "   - macOS: brew install gnupg"
    echo "   - Windows: Install GPG4Win"
    exit 1
fi

# Check if GPG key is available
if [ -z "${GPG_KEY_ID:-}" ]; then
    echo "🔑 GPG Key ID not set in environment variable GPG_KEY_ID"
    echo "📋 Available keys:"
    gpg --list-keys --keyid-format LONG | grep -E "^pub" || echo "No GPG keys found"
    echo ""
    echo "💡 To set your key ID:"
    echo "   export GPG_KEY_ID=YOUR_KEY_ID"
    echo "   ./encrypt-subdomains.sh"
    echo ""
    echo "🛠️  Or run the setup script first:"
    echo "   ./scripts/setup-encryption.sh"
    exit 1
fi

# Quick file check
echo "📊 Analyzing subdomain file..."
TOTAL_LINES=$(wc -l < "$SUBDOMAIN_FILE")

echo "   Total lines: $TOTAL_LINES"
echo "   File size: $(du -h "$SUBDOMAIN_FILE" | cut -f1)"

# Optional validation (only if --validate flag is passed)
if [[ "$*" == *"--validate"* ]]; then
    echo "🔍 Running detailed validation (this may take time for large files)..."
    VALID_SUBDOMAINS=0
    INVALID_LINES=0

    while IFS= read -r line; do
        line=$(echo "$line" | tr -d '\r' | xargs)  # Remove carriage returns and whitespace
        
        # Skip empty lines
        if [ -z "$line" ]; then
            continue
        fi
        
        # Basic subdomain validation
        if echo "$line" | grep -qE '^[a-zA-Z0-9]([a-zA-Z0-9\-]*[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]*[a-zA-Z0-9])?)*$'; then
            VALID_SUBDOMAINS=$((VALID_SUBDOMAINS + 1))
        else
            INVALID_LINES=$((INVALID_LINES + 1))
            if [ $INVALID_LINES -le 5 ]; then
                echo "⚠️  Invalid subdomain: $line"
            fi
        fi
    done < "$SUBDOMAIN_FILE"

    echo "📊 Validation Results:"
    echo "   Valid subdomains: $VALID_SUBDOMAINS"
    echo "   Invalid entries: $INVALID_LINES"

    if [ $INVALID_LINES -gt 0 ]; then
        echo ""
        echo "⚠️  Warning: Found $INVALID_LINES invalid entries"
        echo "🤔 Do you want to continue anyway? (y/N)"
        read -r CONTINUE
        if [[ ! "$CONTINUE" =~ ^[Yy]$ ]]; then
            echo "❌ Encryption cancelled"
            exit 1
        fi
    fi
else
    echo "   Skipping validation (use --validate flag for detailed validation)"
fi

# Check if output file already exists
if [ -f "$OUTPUT_FILE" ]; then
    echo ""
    echo "⚠️  Encrypted file already exists: $OUTPUT_FILE"
    echo "🤔 Do you want to overwrite it? (y/N)"
    read -r OVERWRITE
    if [[ ! "$OVERWRITE" =~ ^[Yy]$ ]]; then
        echo "❌ Encryption cancelled"
        exit 1
    fi
fi

# Encrypt the file
echo ""
echo "🔐 Encrypting subdomain file..."
echo "   Input: $SUBDOMAIN_FILE"
echo "   Output: $OUTPUT_FILE"
echo "   GPG Key: $GPG_KEY_ID"

if gpg --batch --yes --trust-model always \
       --recipient "$GPG_KEY_ID" \
       --encrypt --armor \
       --output "$OUTPUT_FILE" \
       "$SUBDOMAIN_FILE"; then
    
    echo "✅ Subdomain file encrypted successfully!"
    
    # Verify the encrypted file
    if gpg --list-packets "$OUTPUT_FILE" > /dev/null 2>&1; then
        echo "✅ Encrypted file verification passed"
    else
        echo "❌ Encrypted file verification failed"
        exit 1
    fi
    
    # Show file sizes
    ORIGINAL_SIZE=$(du -h "$SUBDOMAIN_FILE" | cut -f1)
    ENCRYPTED_SIZE=$(du -h "$OUTPUT_FILE" | cut -f1)
    
    echo ""
    echo "📊 File Information:"
    echo "   Original file: $ORIGINAL_SIZE"
    echo "   Encrypted file: $ENCRYPTED_SIZE"
    echo "   Subdomains: $VALID_SUBDOMAINS"
    
    echo ""
    echo "🔒 Security Notes:"
    echo "   ✅ The encrypted file is safe to commit to a public repository"
    echo "   ✅ Only holders of the private GPG key can decrypt it"
    echo "   ✅ GitHub Actions will decrypt it automatically using secrets"
    
    echo ""
    echo "📋 Next Steps:"
    echo "   1. Commit the encrypted file to your repository:"
    echo "      git add $OUTPUT_FILE"
    echo "      git commit -m 'Add encrypted subdomain list'"
    echo "      git push"
    echo ""
    echo "   2. (Optional) Remove the unencrypted file for security:"
    echo "      rm $SUBDOMAIN_FILE"
    echo ""
    echo "   3. Configure GitHub Secrets if not done already:"
    echo "      - GPG_PRIVATE_KEY"
    echo "      - GPG_PUBLIC_KEY" 
    echo "      - GPG_KEY_ID"
    
    # Test decryption
    echo ""
    echo "🧪 Testing decryption..."
    TEMP_DECRYPT=$(mktemp)
    if gpg --batch --yes --quiet --decrypt "$OUTPUT_FILE" > "$TEMP_DECRYPT" 2>/dev/null; then
        DECRYPT_LINES=$(wc -l < "$TEMP_DECRYPT")
        if [ "$DECRYPT_LINES" -eq "$TOTAL_LINES" ]; then
            echo "✅ Decryption test passed - $DECRYPT_LINES lines recovered"
        else
            echo "⚠️  Decryption test warning - line count mismatch"
            echo "   Original: $TOTAL_LINES lines"
            echo "   Decrypted: $DECRYPT_LINES lines"
        fi
        rm -f "$TEMP_DECRYPT"
    else
        echo "❌ Decryption test failed"
        echo "   Make sure you have the private key imported"
        rm -f "$TEMP_DECRYPT"
        exit 1
    fi
    
else
    echo "❌ Encryption failed"
    exit 1
fi

echo ""
echo "🎉 Subdomain encryption completed successfully!"
echo "📁 Encrypted file: $OUTPUT_FILE"
