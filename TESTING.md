# 🧪 Testing Guide for Nuclei Mass Scanner

This guide walks you through testing the complete system with your targets.

## 📋 Testing Checklist

### Phase 1: Setup and Encryption ✅

**1. Generate GPG Keys**
```bash
# Run the setup script
./scripts/setup-encryption.sh

# This creates:
# - private-key.asc (keep secure!)
# - public-key.asc 
# - github-secrets-setup.md (instructions)
```

**2. Configure GitHub Secrets**
Go to your repository Settings → Secrets and variables → Actions:
- Add `GPG_PRIVATE_KEY` (content of private-key.asc)
- Add `GPG_PUBLIC_KEY` (content of public-key.asc)  
- Add `GPG_KEY_ID` (the key ID from setup script)

**3. Prepare Your Target List**
```bash
# Create your subdomain file (start small for testing)
cat > subdomains/all-subdomains.txt << EOF
example.com
test.example.com
api.example.com
admin.example.com
app.example.com
EOF

# For real use, add your 1M+ subdomains here
```

**4. Encrypt Your Targets**
```bash
# Set your GPG key ID (from step 1)
export GPG_KEY_ID=YOUR_KEY_ID_HERE

# Encrypt the subdomain file
./scripts/encrypt-subdomains.sh subdomains/all-subdomains.txt

# This creates: subdomains/all-subdomains.txt.gpg
```

**5. Commit Only Encrypted Files**
```bash
# Add encrypted file
git add subdomains/all-subdomains.txt.gpg

# Remove unencrypted file (IMPORTANT!)
rm subdomains/all-subdomains.txt

# Commit and push
git commit -m "Add encrypted target list for testing"
git push origin main
```

### Phase 2: Manual Testing 🔥

**Test with Small Batch First:**
```bash
# Trigger a small test run (batches 1-2 = 2000 subdomains max)
gh workflow run nuclei-mass-scan.yml \
  -f batch_start=1 \
  -f batch_end=2 \
  -f scan_profile=quick

# Or use GitHub web interface:
# Go to Actions → nuclei-mass-scan → Run workflow
# Set: batch_start=1, batch_end=2, scan_profile=quick
```

**Monitor the Test:**
1. Go to Actions tab in your repository
2. Watch the workflow progress
3. Check for any errors in the logs
4. Wait for completion (~6 hours max)

### Phase 3: Verify Results 📊

**1. Check Results Branch**
```bash
# Switch to results branch
git fetch origin
git checkout scan-results

# View the output structure
ls -la output/
ls -la output/latest/
ls -la output/$(date +%Y/%m/%d)/
```

**2. Decrypt and View Results**
```bash
# Decrypt latest results
./scripts/decrypt-results.sh output/latest/ ./test-results

# View decrypted files
ls -la test-results/
cat test-results/consolidated_report_*.json | jq '.'
cat test-results/scan_summary_*.json | jq '.'
```

**3. Analyze Findings**
```bash
# Count total findings
jq '.overall_summary.total_findings' test-results/consolidated_report_*.json

# View critical findings
jq '.[] | select(.info.severity=="critical")' test-results/nuclei_results_*.json

# Group by template
jq 'group_by(."template-id") | map({template: .[0]."template-id", count: length})' test-results/nuclei_results_*.json
```

### Phase 4: Full Scale Testing 🚀

**Once small test works, scale up:**

**Option A: Manual Full Run**
```bash
# Process first 15 batches (15K subdomains)
gh workflow run nuclei-mass-scan.yml \
  -f batch_start=1 \
  -f batch_end=15 \
  -f scan_profile=full
```

**Option B: Enable Automatic Scheduling**
The system will automatically run every 6 hours:
- 00:00 UTC: Batches 1-15 (15K subdomains)
- 06:00 UTC: Batches 16-30 (15K subdomains)  
- 12:00 UTC: Batches 31-45 (15K subdomains)
- 18:00 UTC: Batches 46-60 (15K subdomains)

## 🔍 What to Expect

### During Scanning
```
✅ Workflow starts
✅ GPG keys imported from secrets
✅ Subdomain file decrypted temporarily  
✅ 15 parallel jobs start processing
✅ Each job scans 1000 subdomains with ~6000 templates
✅ Results encrypted and stored in repository
✅ Temporary files cleaned up
✅ Consolidated report generated
```

### Results Structure
```
scan-results/
└── output/
    ├── latest/
    │   ├── consolidated_report_latest.json.gpg     # 📊 Master report
    │   ├── nuclei_results_batch_1_latest.json.gpg # 🎯 Detailed findings
    │   └── scan_summary_batch_1_latest.json.gpg   # 📈 Summary stats
    └── 2024/12/01/
        ├── consolidated_report_20241201_143022.json.gpg
        ├── nuclei_results_batch_1_20241201_143022.json.gpg
        └── scan_summary_batch_1_20241201_143022.json.gpg
```

### Sample Decrypted Output
```json
{
  "host": "api.example.com",
  "template-id": "CVE-2021-44228",
  "info": {
    "name": "Apache Log4j RCE",
    "severity": "critical",
    "tags": ["cve", "rce", "apache"]
  },
  "matched-at": "https://api.example.com/search",
  "timestamp": "2024-12-01T14:30:22Z"
}
```

## 🚨 Troubleshooting

### Common Issues

**1. GPG Decryption Fails**
```bash
# Check if keys are imported
gpg --list-secret-keys

# Re-import if needed
gpg --import private-key.asc
```

**2. Workflow Fails at Subdomain Decryption**
- Verify GitHub Secrets are set correctly
- Check GPG_KEY_ID matches your actual key ID
- Ensure encrypted file is committed to repository

**3. No Results Generated**
- Check if subdomains are reachable
- Verify scan profile settings
- Look for rate limiting issues in workflow logs

**4. Push Conflicts in Results Branch**
- The workflow has retry logic for concurrent pushes
- Check workflow logs for push failures
- Manual resolution may be needed for persistent conflicts

### Debug Commands
```bash
# Test GPG encryption/decryption locally
echo "test" | gpg --encrypt --armor --recipient $GPG_KEY_ID | gpg --decrypt

# Validate subdomain file format
python3 scripts/subdomain-splitter.py validate subdomains/all-subdomains.txt

# Check workflow syntax
gh workflow view nuclei-mass-scan.yml
```

## 📈 Scaling Up

### For 1M+ Subdomains

**Timeline Expectations:**
- **Complete scan cycle**: ~17 days
- **Daily processing**: 60K subdomains  
- **Per workflow run**: 15K subdomains (6 hours)

**Storage Growth:**
- **Per batch**: ~10-50MB encrypted results
- **Full 1M scan**: ~100GB total encrypted data
- **Repository size**: Will grow over time with historical results

**Monitoring:**
- Check Actions tab daily for workflow status
- Monitor repository size (GitHub has 100GB soft limit)
- Review findings in consolidated reports

## ✅ Success Criteria

Your system is working correctly when:

1. ✅ Encrypted subdomain file committed to repository
2. ✅ Workflow runs without errors  
3. ✅ Results appear in scan-results branch
4. ✅ Decryption produces readable JSON files
5. ✅ Findings are relevant to your targets
6. ✅ Automatic scheduling triggers every 6 hours
7. ✅ No sensitive data visible in public repository

## 🎯 Next Steps After Testing

1. **Scale gradually**: Start with 10K subdomains, then 100K, then full list
2. **Monitor performance**: Watch for rate limiting or timeout issues  
3. **Customize templates**: Add your own Nuclei templates if needed
4. **Set up notifications**: Configure alerts for critical findings
5. **Automate analysis**: Build scripts to process results automatically

---

**Remember**: This system is designed for authorized security testing only. Ensure you have permission to scan all target systems!
