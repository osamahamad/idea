# 🎯 Nuclei Mass Scanner for Bug Bounty

A comprehensive GitHub Actions-based solution for scanning over **1 million subdomains** using all Nuclei templates while keeping results encrypted and secure in a public repository.

## 🚀 Features

- **Massive Scale**: Handle 1M+ subdomains with intelligent batching
- **Encrypted Results**: All scan outputs are GPG encrypted before storage
- **Unlimited GitHub Actions**: Leverage free unlimited minutes on public repos
- **Comprehensive Templates**: Uses all available Nuclei templates
- **Parallel Processing**: Up to 20 concurrent scanning jobs
- **Smart Scheduling**: Automatic chunked processing every 6 hours
- **Failure Resilient**: Continues processing even if individual batches fail
- **Progress Monitoring**: Detailed reporting and summaries

## 📋 Architecture Overview

### 🏗️ System Architecture

```
[Private Subdomains] → [Encrypt] → [Public Repo] → [GitHub Actions] → [Encrypted Results] → [Repo Storage]
         ↓                 ↓             ↓               ↓                    ↓                  ↓
  1M+ subdomains    GPG Encryption   Safe Storage   15 Parallel Jobs   GPG Encrypted    scan-results branch
     (.txt)           (.txt.gpg)    (Public Repo)   (6h workflows)      (.json.gpg)      (Organized by date)
```

### 🔐 Security-First Design

**Public Repository Strategy**: 
- ✅ **Subdomains**: Encrypted with GPG before commit (`all-subdomains.txt.gpg`)
- ✅ **Results**: All scan outputs encrypted before storage
- ✅ **Secrets**: GPG keys stored in GitHub Secrets
- ✅ **Zero Exposure**: No sensitive data ever visible in public repo

### ⚡ Parallel Processing Architecture

```
Batch Matrix Generation → 15 Concurrent Runners → Results Consolidation
        ↓                          ↓                        ↓
   [1,2,3,...,15]           Each processes 1K           Combined Report
                            subdomains in parallel
```

### 📊 Data Flow Architecture

```
📁 Input Layer
├── subdomains/all-subdomains.txt.gpg (encrypted, 1M+ domains)
└── GitHub Secrets (GPG keys)

🔄 Processing Layer  
├── Decrypt subdomains (temporary, in-memory)
├── Split into batches (1K per batch)
├── Matrix strategy (15 parallel jobs)
└── Nuclei scanning (all 6K+ templates)

💾 Storage Layer
├── scan-results branch
├── output/YYYY/MM/DD/ (dated results)
├── output/latest/ (quick access)
└── Encrypted .gpg files only
```

## 🔧 How GitHub Actions Workflow Works

### Main Workflow: `nuclei-mass-scan.yml`

#### **Job 1: prepare-batches**
```yaml
# What it does: Calculates how many batches are needed and generates a matrix
Duration: ~30 seconds
Resources: ubuntu-latest (1 core, 7GB RAM)
```

**Step-by-step process:**
1. **Checkout repository** - Downloads your repo with subdomains
2. **Count total subdomains** - Reads `subdomains/all-subdomains.txt` and counts lines
3. **Calculate batches needed** - Divides total by BATCH_SIZE (1000)
4. **Generate matrix** - Creates JSON array like `[1,2,3,...,20]` for parallel jobs
5. **Set batch range** - Determines which batches to process based on input/schedule
6. **Output matrix** - Passes batch numbers to the scanning job

**Example output:**
```
Total subdomains: 1,000,000
Batch size: 1000
Total batches needed: 1000
Processing batches 1-20 (first chunk)
Matrix: [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20]
```

#### **Job 2: nuclei-scan (Matrix Strategy)**
```yaml
# What it does: Runs 15 parallel scanning jobs simultaneously (reduced to avoid GitHub limits)
Duration: ~5h 50m per job (under 6h GitHub limit)
Resources: 15 × ubuntu-latest runners (15 cores total, 105GB RAM total)
Strategy: fail-fast=false (continues even if some batches fail)
```

**Each parallel job processes ONE batch (1000 subdomains):**

**Step 1: Environment Setup (2-3 minutes)**
- Checkout repository code
- **Setup GPG**: Import encryption keys from GitHub Secrets
- **Decrypt subdomains**: Convert `all-subdomains.txt.gpg` → `all-subdomains.txt` (temporary)
- Install Go 1.21
- Install Nuclei v3.1.0: `go install github.com/projectdiscovery/nuclei/v3/cmd/nuclei@v3.1.0`
- Update Nuclei templates: `nuclei -update-templates` (downloads ~6000 templates)

**Step 2: Batch Preparation (10-15 seconds)**
```bash
# For batch #5 (example):
START_LINE=4001  # (5-1) × 1000 + 1
END_LINE=5000    # 5 × 1000
sed -n "4001,5000p" subdomains/all-subdomains.txt > batch_5.txt
# Creates file with exactly 1000 subdomains
```

**Step 3: Scan Configuration (5 seconds)**
Based on scan profile:
```bash
# FULL profile (default):
TEMPLATES="-t ."  # All ~6000 templates
SEVERITY="-severity critical,high,medium,low,info"
RATE_LIMIT="-rl 50"  # 50 requests/second

# QUICK profile:
TEMPLATES="-t cves/ -t vulnerabilities/ -t exposures/"  # ~2000 templates
SEVERITY="-severity critical,high"
RATE_LIMIT="-rl 100"  # Faster scanning

# CRITICAL profile:
TEMPLATES="-t cves/ -t vulnerabilities/"  # ~1500 templates
SEVERITY="-severity critical"
RATE_LIMIT="-rl 150"  # Fastest scanning
```

**Step 4: Nuclei Scanning (5h 30m - 5h 45m)**
```bash
nuclei \
  -l batch_5.txt \                    # Input: 1000 subdomains
  -t . \                              # All templates (~6000)
  -severity critical,high,medium,low,info \
  -rl 50 \                            # 50 requests/second
  -j \                                # JSON output
  -o nuclei_results_batch_5_20241201_143022.json \
  -stats \                            # Show progress stats
  -silent \                           # Reduce noise
  -timeout 10 \                       # 10s timeout per request
  -retries 2 \                        # Retry failed requests
  -bulk-size 50 \                     # Process 50 URLs at once
  -c 25 \                             # 25 concurrent threads
  -header "User-Agent: Mozilla/5.0 (compatible; SecurityScanner/1.0)" \
  -exclude-tags dos,intrusive         # Skip dangerous templates
```

**Real-time scanning process:**
- **Per subdomain**: Tests ~6000 templates = ~6000 HTTP requests
- **Per batch**: 1000 subdomains × 6000 templates = ~6,000,000 requests
- **Rate limiting**: 50 req/sec = ~33 hours of requests compressed into 5h 45m via parallelization
- **Concurrency**: 25 threads × 50 bulk size = handles 1250 concurrent requests
- **Progress**: Shows live stats like "1500/6000000 requests completed (0.025%)"

**Step 5: Results Analysis (30 seconds)**
```bash
# Count findings by severity
CRITICAL=$(jq 'select(.info.severity == "critical")' results.json | wc -l)
HIGH=$(jq 'select(.info.severity == "high")' results.json | wc -l)
# Creates summary: {"total_findings": 156, "critical": 12, "high": 34, ...}
```

**Step 6: GPG Encryption (1-2 minutes)**
```bash
# Import GPG keys from GitHub Secrets
echo "$GPG_PRIVATE_KEY" | gpg --batch --import
echo "$GPG_PUBLIC_KEY" | gpg --batch --import

# Encrypt results file
gpg --batch --yes --trust-model always \
    --recipient "$GPG_KEY_ID" \
    --encrypt --armor \
    --output "nuclei_results_batch_5_20241201_143022.json.gpg" \
    "nuclei_results_batch_5_20241201_143022.json"

# Encrypt summary file  
gpg --batch --yes --trust-model always \
    --recipient "$GPG_KEY_ID" \
    --encrypt --armor \
    --output "scan_summary_batch_5_20241201_143022.json.gpg" \
    "scan_summary_batch_5_20241201_143022.json"

# Delete unencrypted files for security
rm -f *.json
```

**Step 7: Repository Storage (2-3 minutes)**
```bash
# Switch to scan-results branch
git checkout scan-results || git checkout -b scan-results

# Organize encrypted files by date
DATE_DIR="output/$(date +%Y/%m/%d)"
mkdir -p "${DATE_DIR}" "output/latest"

# Store encrypted results with timestamp
mv nuclei_results_batch_5_*.json.gpg "${DATE_DIR}/nuclei_results_batch_5_20241201_143022.json.gpg"
mv scan_summary_batch_5_*.json.gpg "${DATE_DIR}/scan_summary_batch_5_20241201_143022.json.gpg"

# Copy to latest directory for easy access
cp "${DATE_DIR}/"*.gpg "output/latest/"

# Commit and push with retry logic (handles concurrent pushes)
git add output/
git commit -m "🎯 Batch 5 scan results - 67 findings"
git push origin scan-results
```

#### **Job 3: consolidate-results**
```yaml
# What it does: Combines all batch results into one master report
Duration: ~5-10 minutes
Resources: ubuntu-latest
Runs: After all scanning jobs complete (success or failure)
```

**Step-by-step process:**

**Step 1: Access Results from Repository (30 seconds)**
```bash
# Checkout scan-results branch
git checkout scan-results

# Access latest batch results
ls output/latest/*summary*.gpg
# Example: scan_summary_batch_1_latest.gpg, scan_summary_batch_2_latest.gpg, etc.
```

**Step 2: Decrypt and Process (2-3 minutes)**
```bash
# For each batch summary file:
for summary_file in output/latest/*summary*.gpg; do
  gpg --decrypt "$summary_file" > temp_summary.json
  
  # Extract metrics
  BATCH_FINDINGS=$(jq '.results_summary.total_findings' temp_summary.json)
  BATCH_CRITICAL=$(jq '.results_summary.critical' temp_summary.json)
  # Add to running totals...
done
```

**Step 3: Generate Master Report (1 minute)**
```json
{
  "scan_metadata": {
    "timestamp": "20241201_143022",
    "workflow_run_id": "1234567890",
    "total_batches_processed": 20,
    "scan_profile": "full"
  },
  "batch_summaries": [
    {"batch_number": 1, "total_findings": 67, "critical": 3, ...},
    {"batch_number": 2, "total_findings": 89, "critical": 5, ...}
  ],
  "overall_summary": {
    "total_findings": 1337,
    "critical": 23,
    "high": 156,
    "medium": 445,
    "low": 398,
    "info": 315,
    "total_subdomains_scanned": 20000
  }
}
```

**Step 4: Create Workflow Summary**
```markdown
# 🎯 Nuclei Mass Scan Results

## 📊 Scan Overview
- **Total Subdomains Scanned**: 20,000
- **Batches Processed**: 20
- **Total Findings**: 1,337

## 🚨 Findings by Severity
| Severity | Count |
|----------|-------|
| Critical | 23    |
| High     | 156   |
| Medium   | 445   |
| Low      | 398   |
| Info     | 315   |
```

**Step 4: Store Consolidated Report**
```bash
# Store in organized directory structure
DATE_DIR="output/$(date +%Y/%m/%d)"
mkdir -p "${DATE_DIR}" "output/latest"

# Move encrypted consolidated report
mv consolidated_report_*.json.gpg "${DATE_DIR}/consolidated_report_20241201_143022.json.gpg"
cp "${DATE_DIR}/consolidated_report_*.json.gpg" "output/latest/consolidated_report_latest.json.gpg"

# Commit to scan-results branch
git add output/
git commit -m "📊 Consolidated scan report - 2024-12-01 14:30:22 UTC"
git push origin scan-results
```

**Result**: All scan data organized in repository with no cleanup needed - everything is permanent and accessible.

### Scheduled Workflow: `nuclei-scheduled-chunks.yml`

#### **Automatic Processing Strategy**
```yaml
# Runs every 6 hours: 00:00, 06:00, 12:00, 18:00 UTC
# Processes different chunks automatically
```

**Daily Schedule:**
- **00:00 UTC**: Chunk 1 (batches 1-15) = 15,000 subdomains
- **06:00 UTC**: Chunk 2 (batches 16-30) = 15,000 subdomains  
- **12:00 UTC**: Chunk 3 (batches 31-45) = 15,000 subdomains
- **18:00 UTC**: Chunk 4 (batches 46-60) = 15,000 subdomains

**For 1M subdomains:**
- **Total batches needed**: 1,000 batches
- **Chunks needed**: 67 chunks (1000 ÷ 15)
- **Full cycle time**: 67 chunks ÷ 4 per day = 16.75 days
- **Complete coverage**: Every subdomain scanned every ~17 days

#### **Chunk Processing Logic**
```bash
# Determines chunk based on current time
HOUR=$(date +%H)
case $HOUR in
  0|1|2|3|4|5) CHUNK_NUM=1 ;;      # Midnight to 6 AM
  6|7|8|9|10|11) CHUNK_NUM=2 ;;    # 6 AM to Noon  
  12|13|14|15|16|17) CHUNK_NUM=3 ;; # Noon to 6 PM
  *) CHUNK_NUM=4 ;;                # 6 PM to Midnight
esac

# Calculate batch range
BATCH_START=$(( (CHUNK_NUM - 1) * 15 + 1 ))  # Chunk 1: batch 1, Chunk 2: batch 16
BATCH_END=$(( CHUNK_NUM * 15 ))               # Chunk 1: batch 15, Chunk 2: batch 30
```

### Resource Usage & Costs

#### **GitHub Actions Resources (FREE on public repos)**
- **Compute**: 15 parallel runners × 6 hours = 90 runner-hours per scan
- **Storage**: Repository-based (no artifact limits) - ~2GB per full scan cycle
- **Network**: ~50GB download (Nuclei templates) + ~5GB upload (results to repo)
- **Git operations**: Push/pull operations for result storage

#### **Real-world Performance Numbers**
```
1000 subdomains × 6000 templates = 6,000,000 HTTP requests per batch
15 parallel batches = 90,000,000 HTTP requests per workflow run
Rate limit 50/sec × 25 threads × 15 jobs = 18,750 requests/sec theoretical max
Actual throughput: ~8,000-12,000 requests/sec (network/server limitations)
Time per batch: 6M requests ÷ 10k req/sec = ~10 minutes of pure requests
Total time per batch: ~5h 45m (including template matching, analysis, etc.)
```

#### **Scaling Calculations**
```
For 1,000,000 subdomains:
- Total HTTP requests: 6 billion requests
- Total workflow runs needed: 67 runs (1000 batches ÷ 15 per run)  
- Total compute time: 67 runs × 90 hours = 6,030 runner-hours
- Total calendar time: 67 runs × 6 hours = 402 hours = 16.75 days
- Storage per complete scan: ~100GB encrypted data (in scan-results branch)
```

This system efficiently uses GitHub's unlimited Actions minutes on public repos to perform enterprise-scale vulnerability scanning while keeping all sensitive results encrypted and secure.

## 📁 Repository Structure

### Main Branch (Public)
```
nuclei-mass-scanner/
├── .github/workflows/
│   ├── nuclei-mass-scan.yml           # Main scanning workflow
│   └── nuclei-scheduled-chunks.yml    # Automatic scheduling
├── scripts/
│   ├── setup-encryption.sh            # GPG key generation
│   ├── encrypt-subdomains.sh          # Subdomain encryption
│   ├── decrypt-results.sh             # Result decryption
│   └── subdomain-splitter.py          # Batch management
├── subdomains/
│   ├── all-subdomains.txt.gpg         # 🔐 Encrypted subdomain list
│   └── .gitkeep                       # Directory marker
├── .gitignore                          # Security-focused ignore rules
├── README.md                           # This documentation
└── LICENSE                             # MIT license
```

### Scan-Results Branch (Auto-generated)
```
scan-results/
└── output/
    ├── latest/                         # Quick access to latest results
    │   ├── consolidated_report_latest.json.gpg
    │   ├── nuclei_results_batch_1_latest.json.gpg
    │   ├── scan_summary_batch_1_latest.json.gpg
    │   └── ... (all latest batch results)
    └── YYYY/MM/DD/                     # Organized by date
        ├── consolidated_report_20241201_143022.json.gpg
        ├── nuclei_results_batch_1_20241201_143022.json.gpg
        ├── scan_summary_batch_1_20241201_143022.json.gpg
        └── ... (timestamped results)
```

### Security Model
- ✅ **Main branch**: Contains only encrypted data and code
- ✅ **Scan-results branch**: Contains only encrypted scan results  
- ✅ **No sensitive data**: All private information is GPG encrypted
- ✅ **Public repository safe**: Can be shared without exposing assets

## 🛠️ Setup Instructions

### 1. Repository Setup

1. **Create a public GitHub repository** (for unlimited Actions minutes)
2. **Clone this repository** or copy the workflow files
3. **Add your subdomain list** as `subdomains/all-subdomains.txt`

### 2. Encryption Setup

Run the setup script to generate GPG keys:

```bash
chmod +x scripts/setup-encryption.sh
./scripts/setup-encryption.sh
```

This will:
- Generate a GPG key pair
- Export the keys
- Provide instructions for GitHub Secrets setup

### 3. Nuclei Cloud Integration (Optional but Recommended)

For real-time dashboard monitoring and cloud storage:

1. **Get ProjectDiscovery API Key:**
   - Sign up at [https://cloud.nuclei.sh](https://cloud.nuclei.sh)
   - Generate API key from Settings → API Keys

2. **Add to GitHub Secrets:**
   - Go to your repo → Settings → Secrets and variables → Actions
   - Add secret: `PROJECTDISCOVERY_API_KEY`
   - Value: Your API key (starts with `nuclei_`)

3. **Benefits:**
   - Real-time scan monitoring
   - Cloud-based result storage
   - Historical data and trends
   - Better debugging and error reporting

See [NUCLEI-CLOUD-SETUP.md](NUCLEI-CLOUD-SETUP.md) for detailed setup instructions.

### 4. GitHub Secrets Configuration

Add these secrets to your repository (Settings → Secrets and variables → Actions):

| Secret Name | Description | Value |
|-------------|-------------|--------|
| `GPG_PRIVATE_KEY` | Private GPG key for encryption | Content of `private-key.asc` |
| `GPG_PUBLIC_KEY` | Public GPG key | Content of `public-key.asc` |
| `GPG_KEY_ID` | GPG key identifier | Key ID from setup script |
| `PROJECTDISCOVERY_API_KEY` | Nuclei Cloud API key (optional) | API key from [cloud.nuclei.sh](https://cloud.nuclei.sh) |

### 4. Subdomain Preparation

**Important**: Since this is a public repository, subdomains must be encrypted!

```bash
# 1. Create your subdomain file
echo "example.com" > subdomains/all-subdomains.txt
echo "api.example.com" >> subdomains/all-subdomains.txt
# ... add all your 1M+ subdomains

# 2. Validate subdomain format (optional)
python3 scripts/subdomain-splitter.py validate subdomains/all-subdomains.txt

# 3. Set your GPG key ID (from step 2)
export GPG_KEY_ID=YOUR_GPG_KEY_ID_FROM_SETUP

# 4. Encrypt the subdomain file
./scripts/encrypt-subdomains.sh subdomains/all-subdomains.txt

# 5. Commit ONLY the encrypted file
git add subdomains/all-subdomains.txt.gpg
rm subdomains/all-subdomains.txt  # Remove unencrypted file for security
git commit -m "Add encrypted subdomain list"
git push
```

**Security Note**: Never commit the unencrypted `all-subdomains.txt` file to a public repository!

## 🎮 Usage

### Automatic Scheduled Scanning

The system automatically processes your subdomains in chunks:
- **Every 6 hours**: Processes a different chunk (15K subdomains per chunk)
- **4 chunks per day**: Complete coverage of 60K subdomains daily
- **Continuous coverage**: Full 1M+ subdomain scan every ~17 days

### Manual Scanning

#### Full Scan Control
```bash
# Trigger specific batch range
gh workflow run nuclei-mass-scan.yml \
  -f batch_start=1 \
  -f batch_end=50 \
  -f scan_profile=full
```

#### Quick Scan (Critical/High only)
```bash
# Fast scan with critical templates only
gh workflow run nuclei-mass-scan.yml \
  -f batch_start=1 \
  -f batch_end=20 \
  -f scan_profile=quick
```

#### Chunk Processing
```bash
# Process specific chunk (1-4)
gh workflow run nuclei-scheduled-chunks.yml \
  -f chunk_number=1 \
  -f force_full_scan=true
```

### Scan Profiles

| Profile | Templates | Severity | Speed | Use Case |
|---------|-----------|----------|--------|----------|
| `quick` | CVEs, Vulnerabilities, Exposures | Critical, High | Fast | Daily monitoring |
| `full` | All templates | All severities | Slow | Comprehensive audit |
| `critical` | CVEs, Vulnerabilities | Critical only | Medium | Priority findings |

## 📊 Monitoring & Results

### GitHub Actions Dashboard

Monitor your scans through:
- **Actions tab**: View running and completed workflows
- **Workflow summaries**: Quick statistics and findings count
- **Artifacts**: Download encrypted results

### Result Analysis

Access and decrypt results directly from the repository:

```bash
# 1. Switch to the scan-results branch
git checkout scan-results

# 2. View available results
ls -la output/latest/          # Latest results from each batch
ls -la output/2024/12/01/      # Results from specific date

# 3. Decrypt results locally
chmod +x scripts/decrypt-results.sh
./scripts/decrypt-results.sh output/latest/ ./decrypted-results

# 4. Or decrypt specific files manually
gpg --decrypt output/latest/consolidated_report_latest.json.gpg > consolidated_report.json
```

### Result Structure

```json
{
  "scan_metadata": {
    "timestamp": "20241201_143022",
    "total_batches_processed": 50,
    "scan_profile": "full"
  },
  "overall_summary": {
    "total_findings": 1337,
    "critical": 23,
    "high": 156,
    "medium": 445,
    "low": 398,
    "info": 315,
    "total_subdomains_scanned": 50000
  }
}
```

## 🔒 Security Features

### Encryption
- **GPG encryption**: All results encrypted before storage
- **Public repo safe**: No sensitive data exposed
- **Key management**: Secure key generation and handling

### Access Control
- **GitHub Secrets**: Sensitive keys stored securely
- **Artifact retention**: Configurable retention periods
- **Local decryption**: Results only readable with private key

## ⚙️ Configuration

### Batch Size Optimization

Edit `.github/workflows/nuclei-mass-scan.yml`:

```yaml
env:
  BATCH_SIZE: 1000  # Subdomains per batch (adjust based on your needs)
  MAX_PARALLEL_JOBS: 20  # Concurrent jobs (GitHub limit)
```

### Template Customization

Modify scan profiles in the workflow:

```yaml
case $PROFILE in
  "custom")
    TEMPLATES="-t your-custom-templates/"
    SEVERITY="-severity critical,high"
    RATE_LIMIT="-rl 75"
    ;;
esac
```

### Scheduling

Adjust automatic scanning frequency:

```yaml
schedule:
  # Run every 4 hours instead of 6
  - cron: '0 */4 * * *'
```

## 📈 Performance Optimization

### For Large Scale (1M+ subdomains)
- **Batch size**: 1000 subdomains per batch
- **Parallel jobs**: 20 concurrent scans
- **Rate limiting**: 50-100 requests per second per job
- **Timeouts**: 10 seconds per request, 2 retries

### GitHub Actions Limits
- **6-hour workflow limit**: Each batch completes in ~5h50m
- **Unlimited minutes**: Public repositories have no minute restrictions
- **Storage**: 500MB per artifact, automatic cleanup after processing

## 🔧 Troubleshooting

### Common Issues

#### Workflow Timeouts
```bash
# Reduce batch size if workflows timeout
BATCH_SIZE: 500  # Instead of 1000
```

#### GPG Decryption Failures
```bash
# Re-import your private key
gpg --import private-key.asc
gpg --list-secret-keys
```

#### Rate Limiting
```bash
# Adjust rate limits in workflow
RATE_LIMIT="-rl 25"  # Slower but more reliable
```

### Debug Mode

Enable debug logging:

```yaml
- name: Run Nuclei scan
  run: |
    nuclei -debug -v \  # Add debug flags
    # ... rest of command
```

## 📚 Advanced Usage

### Custom Template Integration

```bash
# Add custom templates to your repo
mkdir custom-templates
# Add your .yaml template files
# Update workflow to use: -t custom-templates/
```

### Result Post-Processing

```bash
# Filter critical findings
jq '.[] | select(.info.severity=="critical")' results.json > critical.json

# Group by template
jq 'group_by(.template_id)' results.json > grouped.json

# Export to CSV
jq -r '[.host, .template_id, .info.severity] | @csv' results.json > results.csv
```

### Integration with Other Tools

```yaml
# Add additional scanning tools to workflow
- name: Run additional tools
  run: |
    # subfinder, httpx, etc.
    subfinder -dL batch.txt -o subdomains.txt
    httpx -l subdomains.txt -o live.txt
    nuclei -l live.txt -t templates/
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Test your changes with a small subdomain set
4. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## ⚠️ Disclaimer

- **Legal compliance**: Ensure you have permission to scan all targets
- **Rate limiting**: Respect target server resources
- **Responsible disclosure**: Follow proper vulnerability disclosure practices
- **Terms of service**: Comply with GitHub's terms of service

## 🆘 Support

- **Issues**: Report bugs via GitHub Issues
- **Discussions**: Use GitHub Discussions for questions
- **Security**: Report security issues privately

---

**Built with ❤️ for the bug bounty community**
