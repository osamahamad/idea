# Nuclei Cloud Integration Setup

This workflow now includes Nuclei Cloud integration with real-time dashboard monitoring.

## 🔑 **Required GitHub Secret**

You need to add your ProjectDiscovery API key as a GitHub secret:

### **Secret Name:** `PROJECTDISCOVERY_API_KEY`

### **How to Get Your API Key:**

1. **Sign up for Nuclei Cloud:**
   - Go to [https://cloud.nuclei.sh](https://cloud.nuclei.sh)
   - Create an account or sign in

2. **Get Your API Key:**
   - Go to your dashboard
   - Navigate to Settings → API Keys
   - Generate a new API key
   - Copy the key (it looks like: `nuclei_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`)

3. **Add to GitHub Secrets:**
   - Go to your repository: `https://github.com/osamahamad/idea`
   - Click **Settings** → **Secrets and variables** → **Actions**
   - Click **New repository secret**
   - Name: `PROJECTDISCOVERY_API_KEY`
   - Value: Paste your API key
   - Click **Add secret**

## ☁️ **What This Enables:**

### **Real-time Dashboard:**
- View scan progress in real-time at [https://cloud.nuclei.sh](https://cloud.nuclei.sh)
- Monitor multiple batches running in parallel
- See live statistics and findings as they're discovered

### **Cloud Storage:**
- Results are automatically uploaded to Nuclei Cloud
- Access results from anywhere via the web dashboard
- Historical scan data and trends

### **Enhanced Features:**
- Better error reporting and debugging
- Cloud-based template updates
- Collaborative features (if using team accounts)

## 🔧 **Workflow Integration:**

The workflow now includes:
```bash
nuclei \
  # ... other arguments ...
  -auth "${{ secrets.PROJECTDISCOVERY_API_KEY }}" \
  -dashboard \
  # ... rest of command ...
```

## 📊 **Dashboard Features:**

Once scans are running, you can:

1. **Monitor Progress:**
   - See which targets are being scanned
   - View real-time statistics
   - Track completion percentage

2. **View Results:**
   - Browse findings by severity
   - Filter by vulnerability type
   - Export results in various formats

3. **Track History:**
   - Compare scans over time
   - Identify trends and patterns
   - Generate reports

## 🚨 **Security Notes:**

- The API key is stored securely in GitHub Secrets
- It's only accessible during workflow execution
- The key is not logged or exposed in workflow output
- You can rotate/regenerate the key anytime from Nuclei Cloud

## 🔄 **Fallback Behavior:**

If the API key is not set or invalid:
- The scan will still run normally
- Results will be saved locally and encrypted
- You'll see a warning in the logs
- No dashboard integration will occur

## 📝 **Troubleshooting:**

### **"Invalid API key" error:**
- Verify the key is correct in GitHub Secrets
- Check that the key is active in Nuclei Cloud
- Ensure there are no extra spaces or characters

### **"Dashboard not accessible" error:**
- Check your internet connection
- Verify Nuclei Cloud is accessible
- Try regenerating the API key

### **No results in dashboard:**
- Ensure the scan is actually running
- Check that targets are reachable
- Verify template selection is correct

## 🎯 **Benefits:**

1. **Real-time Monitoring:** Watch scans progress live
2. **Better Debugging:** See exactly where scans fail
3. **Cloud Storage:** Results backed up automatically
4. **Team Collaboration:** Share results with team members
5. **Historical Data:** Track security posture over time

---

**Note:** This integration is optional. The workflow will work without the API key, but you'll miss out on the real-time dashboard and cloud storage features.
