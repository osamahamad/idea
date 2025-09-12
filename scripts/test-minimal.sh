#!/bin/bash

# Create a minimal test for GitHub Actions
# This creates just 5 subdomains to test the workflow quickly

set -e

echo "🧪 Creating Minimal Test (5 subdomains)"
echo "======================================"

# Create minimal test file
TEST_FILE="subdomains/test-minimal.txt"
mkdir -p subdomains

echo "📝 Creating minimal test file with 5 subdomains..."
cat > "$TEST_FILE" << EOF
httpbin.org
jsonplaceholder.typicode.com
reqres.in
example.com
google.com
EOF

echo "✅ Created test file: $TEST_FILE ($(wc -l < "$TEST_FILE") subdomains)"

# Check if GPG key ID is set
if [ -z "${GPG_KEY_ID:-}" ]; then
    GPG_KEY_ID=$(gpg --list-secret-keys --keyid-format LONG | grep -E '^sec' | head -1 | awk '{print $2}' | cut -d'/' -f2)
    echo "🔑 Auto-detected GPG Key ID: $GPG_KEY_ID"
    export GPG_KEY_ID
fi

# Encrypt the test file
echo "🔐 Encrypting test file..."
if ./scripts/encrypt-subdomains.sh "$TEST_FILE"; then
    echo "✅ Test file encrypted: ${TEST_FILE}.gpg"
else
    echo "❌ Failed to encrypt test file"
    exit 1
fi

# Backup original file if it exists
if [ -f "subdomains/all-subdomains.txt.gpg" ]; then
    echo "💾 Backing up original subdomain file..."
    cp "subdomains/all-subdomains.txt.gpg" "subdomains/all-subdomains.txt.gpg.backup"
fi

# Replace with test file
echo "🔄 Replacing main subdomain file with minimal test file..."
cp "${TEST_FILE}.gpg" "subdomains/all-subdomains.txt.gpg"

echo ""
echo "✅ Minimal test batch ready!"
echo ""
echo "📋 Next steps:"
echo "   1. Commit the test file:"
echo "      git add subdomains/all-subdomains.txt.gpg"
echo "      git commit -m 'Add minimal test batch (5 subdomains)'"
echo "      git push"
echo ""
echo "   2. Trigger GitHub Actions test:"
echo "      - Go to Actions → 'Nuclei Mass Vulnerability Scan'"
echo "      - Click 'Run workflow'"
echo "      - Set: batch_start=1, batch_end=1, scan_profile=quick"
echo ""
echo "   3. This should complete in ~2-5 minutes and show results!"
echo ""
echo "🎯 Expected: Should find vulnerabilities on httpbin.org and jsonplaceholder.typicode.com"

# Cleanup
rm -f "$TEST_FILE" "${TEST_FILE}.gpg"
