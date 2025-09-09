#!/bin/bash

# Test GPG setup exactly like GitHub Actions does
# This simulates the GitHub Actions GPG setup process

set -e

echo "🧪 Testing GitHub Actions GPG Setup"
echo "==================================="

# Check if GPG key files exist
if [ ! -f "private-key.asc" ] || [ ! -f "public-key.asc" ]; then
    echo "❌ GPG key files not found"
    echo "💡 Run: ./scripts/setup-encryption.sh first"
    exit 1
fi

# Get the key ID
if [ -z "${GPG_KEY_ID:-}" ]; then
    GPG_KEY_ID=$(gpg --list-secret-keys --keyid-format LONG | grep -E '^sec' | head -1 | awk '{print $2}' | cut -d'/' -f2)
    echo "🔑 Auto-detected GPG Key ID: $GPG_KEY_ID"
fi

echo "🔄 Simulating GitHub Actions GPG setup..."

# Clear existing GPG state (simulate fresh runner)
rm -rf ~/.gnupg-test
mkdir ~/.gnupg-test
export GNUPGHOME=~/.gnupg-test

echo "📝 Step 1: Import private key (like GitHub Actions)..."
cat private-key.asc | gpg --batch --import

echo "📝 Step 2: Import public key (like GitHub Actions)..."
cat public-key.asc | gpg --batch --import

echo "📝 Step 3: Verify GPG setup..."
gpg --list-secret-keys --keyid-format LONG
echo "✅ GPG keys imported successfully"

echo ""
echo "🧪 Testing encryption (like results encryption)..."

# Create test data
TEST_DATA="test-data.json"
cat > "$TEST_DATA" << EOF
{
  "host": "example.com",
  "template-id": "test-template",
  "info": {
    "name": "Test Finding",
    "severity": "info"
  }
}
EOF

# Test encryption (same as workflow)
echo "🔐 Testing encryption..."
if gpg --batch --yes --trust-model always \
       --recipient "$GPG_KEY_ID" \
       --encrypt --armor \
       --output "$TEST_DATA.gpg" \
       "$TEST_DATA"; then
    echo "✅ Encryption successful"
else
    echo "❌ Encryption failed"
    exit 1
fi

# Test decryption (same as workflow)
echo "🔓 Testing decryption..."
if gpg --batch --yes --quiet --trust-model always \
       --decrypt "$TEST_DATA.gpg" > "$TEST_DATA.decrypted" 2>/dev/null; then
    echo "✅ Decryption successful"
    
    # Verify content
    if diff -q "$TEST_DATA" "$TEST_DATA.decrypted" >/dev/null; then
        echo "✅ Content verification passed"
    else
        echo "❌ Content verification failed"
        exit 1
    fi
else
    echo "❌ Decryption failed"
    exit 1
fi

# Cleanup
rm -f "$TEST_DATA" "$TEST_DATA.gpg" "$TEST_DATA.decrypted"
rm -rf ~/.gnupg-test
unset GNUPGHOME

echo ""
echo "🎉 GitHub Actions GPG simulation successful!"
echo "✅ Your GPG keys are compatible with the GitHub Actions workflow"
echo ""
echo "📋 Summary:"
echo "   ✅ GPG import works (no trust issues)"
echo "   ✅ Encryption works with recipient key ID"
echo "   ✅ Decryption works with trust-model always"
echo "   ✅ Content integrity maintained"
echo ""
echo "🚀 Ready for GitHub Actions deployment!"
