#!/bin/bash

# Setup script for GPG encryption keys
# This script helps generate and configure GPG keys for encrypting scan results

set -e

echo "🔐 Setting up GPG encryption for Nuclei scan results"
echo "=================================================="

# Check if GPG is installed
if ! command -v gpg &> /dev/null; then
    echo "❌ GPG is not installed. Please install it first:"
    echo "   - Ubuntu/Debian: sudo apt-get install gnupg"
    echo "   - macOS: brew install gnupg"
    echo "   - Windows: Install GPG4Win"
    exit 1
fi

# Generate GPG key if it doesn't exist
echo "🔑 Checking for existing GPG keys..."
EXISTING_KEYS=$(gpg --list-secret-keys --keyid-format LONG | grep -E "^sec" | wc -l)

if [ "$EXISTING_KEYS" -eq 0 ]; then
    echo "📝 No GPG keys found. Generating new key pair..."
    
    # Create GPG key generation config
    cat > gpg-key-config << EOF
Key-Type: RSA
Key-Length: 4096
Subkey-Type: RSA
Subkey-Length: 4096
Name-Real: Nuclei Scanner
Name-Email: nuclei-scanner@yourdomain.com
Expire-Date: 2y
%no-protection
%commit
EOF

    echo "🔄 Generating GPG key pair (this may take a while)..."
    gpg --batch --generate-key gpg-key-config
    rm gpg-key-config
    
    echo "✅ GPG key pair generated successfully!"
else
    echo "✅ Found existing GPG keys"
fi

# Get the key ID
KEY_ID=$(gpg --list-secret-keys --keyid-format LONG | grep -E "^sec" | head -1 | awk '{print $2}' | cut -d'/' -f2)

if [ -z "$KEY_ID" ]; then
    echo "❌ Could not determine GPG key ID"
    exit 1
fi

echo "🆔 Using GPG Key ID: $KEY_ID"

# Export keys
echo "📤 Exporting GPG keys..."
gpg --armor --export-secret-keys "$KEY_ID" > private-key.asc
gpg --armor --export "$KEY_ID" > public-key.asc

echo "🔐 GPG keys exported:"
echo "   - Private key: private-key.asc"
echo "   - Public key: public-key.asc"

# Create GitHub secrets setup instructions
cat > github-secrets-setup.md << EOF
# GitHub Secrets Setup

To configure your repository for encrypted Nuclei scanning, add these secrets to your GitHub repository:

## Required Secrets

1. **GPG_PRIVATE_KEY**
   - Go to: Repository Settings → Secrets and variables → Actions → New repository secret
   - Name: \`GPG_PRIVATE_KEY\`
   - Value: Copy the entire content of \`private-key.asc\`

2. **GPG_PUBLIC_KEY**
   - Name: \`GPG_PUBLIC_KEY\`
   - Value: Copy the entire content of \`public-key.asc\`

3. **GPG_KEY_ID**
   - Name: \`GPG_KEY_ID\`
   - Value: \`${KEY_ID}\`

## Security Notes

- Keep the private key file (\`private-key.asc\`) secure and delete it from this system after adding to GitHub secrets
- The public key can be shared safely
- Never commit these keys to your repository

## Decrypting Results Locally

To decrypt scan results on your local machine:

\`\`\`bash
# Import your private key (one time setup)
gpg --import private-key.asc

# Decrypt a results file
gpg --decrypt encrypted-results.gpg > decrypted-results.json
\`\`\`

## Key Management

- Keys expire in 2 years - you'll need to regenerate them before expiration
- To list your keys: \`gpg --list-secret-keys --keyid-format LONG\`
- To delete keys: \`gpg --delete-secret-keys ${KEY_ID} && gpg --delete-keys ${KEY_ID}\`
EOF

echo ""
echo "✅ Setup completed successfully!"
echo ""
echo "📋 Next steps:"
echo "   1. Review the GitHub secrets setup instructions: github-secrets-setup.md"
echo "   2. Add the three secrets to your GitHub repository"
echo "   3. Delete the private-key.asc file from this system for security"
echo "   4. Keep the public-key.asc file for reference"
echo ""
echo "🔒 Your GPG Key ID: $KEY_ID"
echo ""
echo "⚠️  IMPORTANT: Keep your private key secure and never commit it to the repository!"
