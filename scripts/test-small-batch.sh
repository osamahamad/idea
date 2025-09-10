#!/bin/bash

# Create a small test batch for quick GitHub Actions testing
# This helps verify the workflow works before running large scans

set -e

echo "🧪 Creating Small Test Batch"
echo "============================"

# Create a small test subdomain file
TEST_FILE="subdomains/test-small.txt"
mkdir -p subdomains

echo "📝 Creating small test file with 10 subdomains..."
cat > "$TEST_FILE" << EOF
httpbin.org
jsonplaceholder.typicode.com
reqres.in
postman-echo.com
httpstat.us
example.com
google.com
github.com
stackoverflow.com
reddit.com
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
echo "🔄 Replacing main subdomain file with test file..."
cp "${TEST_FILE}.gpg" "subdomains/all-subdomains.txt.gpg"

echo ""
echo "✅ Small test batch ready!"
echo ""
echo "📋 Next steps:"
echo "   1. Commit the test file:"
echo "      git add subdomains/all-subdomains.txt.gpg"
echo "      git commit -m 'Add small test batch for workflow testing'"
echo "      git push"
echo ""
echo "   2. Trigger GitHub Actions test:"
echo "      - Go to Actions → 'Nuclei Mass Vulnerability Scan'"
echo "      - Click 'Run workflow'"
echo "      - Set: batch_start=1, batch_end=1, scan_profile=quick"
echo ""
echo "   3. After successful test, restore original file:"
echo "      ./scripts/restore-original-subdomains.sh"
echo ""
echo "🎯 This test should complete in ~10-15 minutes instead of 5+ hours!"

# Create restore script
cat > scripts/restore-original-subdomains.sh << 'EOF'
#!/bin/bash

echo "🔄 Restoring original subdomain file..."

if [ -f "subdomains/all-subdomains.txt.gpg.backup" ]; then
    cp "subdomains/all-subdomains.txt.gpg.backup" "subdomains/all-subdomains.txt.gpg"
    rm "subdomains/all-subdomains.txt.gpg.backup"
    echo "✅ Original subdomain file restored"
    echo ""
    echo "📋 Next steps:"
    echo "   git add subdomains/all-subdomains.txt.gpg"
    echo "   git commit -m 'Restore original subdomain list'"
    echo "   git push"
else
    echo "❌ No backup file found"
    exit 1
fi
EOF

chmod +x scripts/restore-original-subdomains.sh
echo "📝 Created restore script: scripts/restore-original-subdomains.sh"

# Cleanup
rm -f "$TEST_FILE" "${TEST_FILE}.gpg"
