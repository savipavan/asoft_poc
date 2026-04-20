# DevSecOps Pipeline: Complete Execution & Monitoring Guide

This comprehensive guide walks you through executing the Terraform CI/CD pipeline via GitHub Actions, capturing artifacts, publishing results, reviewing logs, and monitoring deployment health through Azure Log Analytics.

---

## 📖 Table of Contents

1. [GitHub Actions Workflow Overview](#1-github-actions-workflow-overview)
2. [Running the Pipeline: Step-by-Step](#2-running-the-pipeline-step-by-step)
3. [Capturing & Publishing Artifacts](#3-capturing--publishing-artifacts)
4. [GitHub Actions Logs: Complete Guide](#4-github-actions-logs-complete-guide)
5. [Azure Log Analytics: Monitoring Deployment](#5-azure-log-analytics-monitoring-deployment)
6. [End-to-End Troubleshooting](#6-end-to-end-troubleshooting)

---

## 1. GitHub Actions Workflow Overview

### Pipeline Architecture

The DevSecOps pipeline consists of **2 sequential jobs**:

| Job | Name | Trigger | Duration | Success Criteria |
|-----|------|---------|----------|------------------|
| **1** | `terraform` (Validate & Plan) | Always | ~2-3 min | ✅ All checks pass |
| **2** | `deploy` (Apply) | Only on `main` branch | ~15-20 min | ✅ Apply succeeds |

### Pipeline Stages Breakdown

```
GitHub Push/PR
       ↓
┌──────────────────────────────────────────┐
│ JOB 1: Terraform Validate & Plan         │
├──────────────────────────────────────────┤
│  ✓ Checkout repository                   │
│  ✓ Set up Terraform 1.7.0                │
│  ✓ Install tfsec v1.32.4                 │
│  ✓ Terraform Init                        │
│  ✓ Terraform Format Check                │
│  ✓ Terraform Validate                    │
│  ✓ Terraform Static Analysis (tfsec)     │
│  ✓ Azure Login (if authenticated)        │
│  ✓ Terraform Plan                        │
└──────────────────────────────────────────┘
       ↓
   [Wait for approval if PR]
       ↓
   ┌─ Branch = main? ──────────┐
   │                           │
   │ YES                       │ NO
   ↓                           ↓
┌─────────────────────┐   [STOP - Plan only]
│ JOB 2: Deploy       │
├─────────────────────┤
│ ✓ Checkout repo    │
│ ✓ Set up TF 1.7.0  │
│ ✓ Azure Login      │
│ ✓ Terraform Init   │
│ ✓ Apply -auto-approve
│ ✓ Retrieve Outputs │
└─────────────────────┘
       ↓
   [Deployment Complete]
```

### Trigger Events

The pipeline is triggered automatically on:

1. **Push to main branch** — Full pipeline (validate → deploy)
2. **Pull Request to main** — Validation only (no deploy)
3. **Manual workflow dispatch** — Can run from GitHub Actions UI

**What Each Trigger Does:**

- **Push to main**: Runs both jobs. If validation passes, deploy automatically applies
- **Pull Request**: Runs job 1 only (validate/plan). Results shown in PR comment
- **Manual trigger**: Same as push (full pipeline execution)

### Pipeline Secrets & Permissions

The pipeline requires the `AZURE_CREDENTIALS` secret configured in GitHub:

```
Settings > Secrets and variables > Actions > AZURE_CREDENTIALS
```

**Format:**
```json
{
  "clientId": "YOUR_CLIENT_ID",
  "clientSecret": "YOUR_CLIENT_SECRET",
  "subscriptionId": "YOUR_SUBSCRIPTION_ID",
  "tenantId": "YOUR_TENANT_ID"
}
```

---

## 2. Running the Pipeline: Step-by-Step

### Option A: Automatic Trigger (Push to main)

#### **Step 1: Commit and Push**

```bash
# Make changes to terraform files
git add main.tf terraform.tfvars

# Commit with clear message
git commit -m "feat: update APIM configuration"

# Push to main (triggers pipeline automatically)
git push origin main
```

**Result**: Pipeline starts automatically on GitHub

---

#### **Step 2: Monitor Execution in GitHub Actions UI**

**Path**: `https://github.com/YOUR_ORG/YOUR_REPO/actions`

**Visual Steps:**

```
1. Open your GitHub repository
2. Click "Actions" tab (top navigation)
3. Look for "Terraform CI/CD" workflow in the left sidebar
4. Click the latest run (top of the list)
5. You'll see:
   - Overall status (yellow=running, green=passed, red=failed)
   - Job list on the left (terraform, deploy)
   - Real-time log viewer on the right
```

**What You'll See:**

```
Terraform CI/CD #15

Status: In progress ⏳

Jobs:
  ✓ terraform (Validate & Plan)  2m 15s
    └─ Terraform Plan step: 45s
  
  ⏳ deploy (Apply & Deploy)      running...
    └─ Terraform Apply step: in progress
```

---

#### **Step 3: Watch Real-Time Logs**

**In GitHub Actions UI:**

1. Click the **"terraform"** job to see validation steps
2. Click each step to expand logs:
   - "Terraform Format Check" — Code formatting validation
   - "Terraform Validate" — Configuration syntax validation
   - "Terraform Static Analysis (tfsec)" — Security scan results
   - "Terraform Plan" — What resources will change

3. Once job 1 completes, click **"deploy"** job to watch apply

**Real-Time Log Output Example:**

```
Terraform Plan
───────────────────────────
Acquiring state lock. This may take a few moments...
Refreshing state... [id=/subscriptions/.../resourceGroups/MyPoCRG]

Plan: 0 to add, 1 to change, 0 to destroy.

Saved the plan to tfplan
───────────────────────────

Next step: Apply phase (if on main branch)
```

---

#### **Step 4: Verify Deployment Completion**

**Job completion indicators:**

```
✅ terraform job PASSED
   └─ All 9 steps completed successfully
   └─ No format/validation/security issues found

✅ deploy job PASSED (only if on main)
   └─ All 6 steps completed successfully
   └─ Terraform Apply succeeded
   └─ Resources deployed to Azure
```

**Expected timing:**

- Validation job: 2-3 minutes
- Deployment job: 15-20 minutes
- **Total**: ~20-25 minutes end-to-end

---

### Option B: Pull Request Workflow (Validation Only)

#### **Step 1: Create a Pull Request**

```bash
# Create feature branch
git checkout -b feature/apim-update

# Make terraform changes
vim main.tf

# Commit and push
git add main.tf
git commit -m "Update APIM SKU configuration"
git push origin feature/apim-update
```

#### **Step 2: Open PR on GitHub**

1. Go to repository on GitHub
2. Click "New Pull Request"
3. Select: `base: main` ← `compare: feature/apim-update`
4. Click "Create Pull Request"

**Result**: Pipeline starts automatically for validation only

#### **Step 3: Review PR Checks**

In PR page, scroll to **"Checks"** section:

```
Terraform CI/CD

✓ terraform (Validate & Plan) — Passed
  └─ View Details: Click to see full logs
  └─ Plan output shows: "Plan: X to add, Y to change, Z to destroy"
```

The PR shows:
- ✅ Code formatting is correct
- ✅ Terraform configuration is valid
- ✅ No security issues (tfsec passed)
- ✅ Plan preview (what will change)

#### **Step 4: Merge to Deploy**

Once PR checks pass:

1. Click "Squash and merge" (or "Merge pull request")
2. Confirm merge
3. Pipeline automatically runs deploy job on main branch
4. Monitor via Actions tab as in Option A

---

### Option C: Manual Workflow Dispatch (GitHub Actions UI)

#### **Step 1: Trigger Manual Run**

1. Go to `https://github.com/YOUR_ORG/YOUR_REPO/actions`
2. Click **"Terraform CI/CD"** workflow name (left sidebar)
3. Click **"Run workflow"** button (blue, top right)
4. Leave "Branch: main" selected
5. Click **"Run workflow"** again to confirm

**Result**: Pipeline starts immediately with full execution

#### **Step 2: Monitor**

Same as Option A, Step 2-4

---

## 3. Capturing & Publishing Artifacts

### What Gets Captured During Pipeline Execution

| Artifact | Size | Location | Contains | When Saved |
|----------|------|----------|----------|-----------|
| **tfplan** | ~500KB | GitHub Actions | Terraform execution plan (binary) | After Plan step |
| **Terraform Logs** | ~100KB | Job logs | Init, validate, plan output | Each step |
| **tfsec Report** | ~50KB | Job logs | Security scan findings | After tfsec step |
| **Job Logs** | ~200KB | GitHub Actions | Complete step-by-step output | After job completes |

### Option A: Download Artifacts from GitHub Actions UI

#### **Step 1: Navigate to Completed Run**

1. Go to Actions tab
2. Click workflow run (e.g., "Terraform CI/CD #15")
3. Click **"terraform"** job
4. Scroll down to **"Artifacts"** section

#### **Step 2: Download Artifacts**

Available artifacts to download:

```
📦 Artifacts
  ├─ tfplan (529 KB)           [Download] — Terraform binary plan
  └─ (No separate log exports)
```

**To download logs:**

1. Click **"terraform"** job
2. Click **⋯** (three dots, top right)
3. Select **"Download logs"**
4. Browser downloads ZIP containing all step logs

---

#### **Step 3: View Downloaded Logs**

```powershell
# Extract downloaded logs
Expand-Archive -Path terraform.zip -DestinationPath terraform_logs

# View formatted logs
Get-ChildItem terraform_logs -Recurse | Where {$_.Extension -eq '.txt'} | ForEach {
    Write-Host "=== $($_.Name) ===" -ForegroundColor Green
    Get-Content $_.FullName | Select-Object -Last 30
}
```

**Log files contain:**

- `1_Checkout repository.txt` — Git checkout output
- `4_Terraform Init.txt` — Provider initialization
- `5_Terraform Format Check.txt` — Code formatting check
- `6_Terraform Validate.txt` — Configuration syntax
- `7_Terraform Static Analysis (tfsec).txt` — Security scan results
- `8_Terraform Plan.txt` — Proposed infrastructure changes

---

### Option B: Retrieve Using GitHub CLI

#### **Prerequisites**

```bash
# Install GitHub CLI
# Windows: choco install gh
# macOS: brew install gh

# Authenticate
gh auth login

# Select: GitHub.com
# Select: HTTPS
# Authenticate with browser
```

#### **List All Workflow Runs**

```bash
# View recent runs
gh run list --workflow=terraform-ci-cd.yml --limit 10

# Output example:
# STATUS  CONCLUSION  WORKFLOW             NAME                  COMMIT           BRANCH  RUN ID      CREATED
# ✓       success     terraform-ci-cd.yml  Terraform CI/CD #15   abc1234def       main    5648394629  2026-04-20T14:32:15Z
# ✓       success     terraform-ci-cd.yml  Terraform CI/CD #14   xyz9876abc       main    5648293015  2026-04-20T13:45:22Z
# ✗       failure     terraform-ci-cd.yml  Terraform CI/CD #13   foo5432bar       main    5648185902  2026-04-20T12:10:01Z
```

#### **Download Specific Run Logs**

```bash
# Download logs for a specific run
gh run download 5648394629 --dir ./github_logs

# List downloaded files
ls -la ./github_logs/

# Output structure:
# terraform/
#   ├─ 1_Checkout repository.txt
#   ├─ 4_Terraform Init.txt
#   ├─ 7_Terraform Static Analysis (tfsec).txt
#   ├─ 8_Terraform Plan.txt
#   └─ ...
# deploy/
#   ├─ 1_Checkout repository.txt
#   ├─ 4_Terraform Apply.txt
#   └─ ...
```

#### **View Specific Step Logs**

```bash
# View tfsec security scan results
cat ./github_logs/terraform/7_Terraform\ Static\ Analysis\ \(tfsec\).txt

# Example output:
# ──────────────────────────────────────────
# tfsec found 2 issues (1 warning, 1 notice)
#
# aws-s3-enable-bucket-encryption
#   Status: WARNING
#   File: main.tf:45
#   Message: Bucket does not have encryption enabled
```

---

### Option C: Parse tfsec Security Findings

#### **Extract Security Scan Results**

```bash
# Run tfsec locally to get JSON output
tfsec . --format json > tfsec-report.json

# Or parse from GitHub logs
gh run download <RUN_ID> --dir logs
cat logs/terraform/7_Terraform\ Static\ Analysis\ \(tfsec\).txt | grep -E "Rule:|Status:|File:" > tfsec_summary.txt
```

#### **Common tfsec Findings**

```
✓ PASSED: Key Vault soft delete enabled
✓ PASSED: API Management system-assigned managed identity
⚠ WARNING: Application Gateway missing WAF on specific rule
ℹ NOTICE: Explicit naming convention recommended for subnets
```

---

### Option D: Publish Results to GitHub Releases

#### **Create a Release with Artifacts**

```bash
# After successful pipeline run, create a release
gh release create v1.0.0-deployment-20260420 \
  --title "BIAN API Infrastructure Deployment" \
  --notes "Terraform apply completed successfully. 
  
## Changes:
- Updated APIM throttling policies
- Enhanced WAF rules
- Expanded Log Analytics retention

## Artifacts:
- See tfplan binary for deployment changes
- Security scan: tfsec passed all checks
- Performance: API deployed within SLA

## Deployment Info:
- Timestamp: 2026-04-20T14:32:15Z
- Region: East US
- Resources: 13 total
- Status: ✅ Production Ready"
```

#### **Attach tfplan as Release Asset**

```bash
# Download tfplan first
gh run download <RUN_ID> --dir artifacts

# Upload to release
gh release upload v1.0.0-deployment-20260420 artifacts/tfplan \
  --clobber
```

---

### Option E: Add Deployment Badges to README

Add deployment status badge to README.md:

```markdown
## Deployment Status

[![Terraform CI/CD](https://github.com/YOUR_ORG/YOUR_REPO/actions/workflows/terraform-ci-cd.yml/badge.svg?branch=main)](https://github.com/YOUR_ORG/YOUR_REPO/actions/workflows/terraform-ci-cd.yml)

Latest deployment: ✅ Main branch - Passing
```

**Badge updates automatically** with pipeline status

---

## 4. GitHub Actions Logs: Complete Guide

### Accessing GitHub Actions Logs

#### **Method 1: GitHub Actions UI (Recommended)**

**Navigation:**

```
Repository > Actions > Terraform CI/CD > Latest Run > Job > Step
```

**Visual Steps:**

1. Open your GitHub repository
2. Click **"Actions"** tab (top navigation bar)
3. Click **"Terraform CI/CD"** workflow (left sidebar)
4. Click the workflow run you want to review (main list)
5. Click **"terraform"** or **"deploy"** job
6. Click individual steps to expand logs

**Real-Time Features:**

- ✅ View logs as they stream during execution
- ✅ Search logs with `Ctrl+F`
- ✅ Download individual step logs
- ✅ Copy log content to clipboard

---

#### **Method 2: GitHub CLI (Batch Processing)**

**List recent runs:**

```bash
gh run list --workflow=terraform-ci-cd.yml --limit 20 --json status,conclusion,name,createdAt,number

# Output:
# NUMBER  NAME                  STATUS     CONCLUSION  CREATED
# 20      Terraform CI/CD #20   COMPLETED  success     2026-04-20T16:00:00Z
# 19      Terraform CI/CD #19   COMPLETED  failure     2026-04-20T15:30:00Z
# 18      Terraform CI/CD #18   COMPLETED  success     2026-04-20T15:00:00Z
```

**Download all logs:**

```bash
gh run download 5648394629 --dir run-20260420-logs

# View directory structure
tree run-20260420-logs /F
```

**View specific job logs:**

```bash
# View terraform validation job logs
cat run-20260420-logs/terraform/5_Terraform\ Validate.txt

# Search for errors
grep -i "error" run-20260420-logs/terraform/*.txt
```

---

### Interpreting Log Output

#### **Successful Terraform Plan**

```
Terraform Plan
──────────────────────────────────────────────────

Reading state file...
Refreshing state... [id=/subscriptions/xxx/resourceGroups/MyPoCRG]

Proposed changes:

# azurerm_api_management.poc_apim will be updated in-place
  ~ resource "azurerm_api_management" "poc_apim" {
      ~ name = "MyPoCAPIM" → "MyPoCAPIM-v2"
      ~ sku_name = "Consumption_0" → "Developer_1"
    }

Plan: 0 to add, 1 to change, 0 to destroy.

Saved the plan to: tfplan
```

**What this means:**

- ✅ No errors reading state
- ✅ 0 new resources being created
- ✅ 1 resource being modified (APIM SKU change)
- ✅ 0 resources being deleted
- ✅ Plan saved to binary file for apply phase

---

#### **Successful Terraform Apply**

```
Terraform Apply
──────────────────────────────────────────────────

Acquiring state lock. This may take a few moments...

Applying tfplan...

azurerm_api_management.poc_apim: Modifying... [id=/subscriptions/.../service/MyPoCAPIM]
azurerm_api_management.poc_apim: Modification complete! [id=/subscriptions/.../service/MyPoCAPIM]

Apply complete! Resources: 0 added, 1 changed, 0 destroyed.

Outputs:

apim_gateway_url = "https://mypocapim.azure-api.net"
app_gateway_public_ip = "168.61.54.72"
log_analytics_workspace_id = "/subscriptions/.../workspaces/MyPoC-LogAnalytics"
```

**What this means:**

- ✅ State lock acquired (prevents concurrent modifications)
- ✅ Plan applied successfully
- ✅ Resource modified (no errors)
- ✅ Outputs retrieved (infrastructure ready)

---

#### **tfsec Security Scan Output**

```
Terraform Static Analysis (tfsec)
──────────────────────────────────────────────────

Run started at 2026-04-20T14:32:15Z

tests run: 142
passed: 140
failed: 0
skipped: 2

2 skipped checks:
  - azure-network-subnet-defined-service-endpoints
    (not applicable to this configuration)
  - azure-network-disable-tcp-fragmentation
    (network infrastructure not using fragmentation)

No security issues found ✅
```

**What this means:**

- ✅ Security scan completed successfully
- ✅ 140 security tests passed
- ✅ 0 failures (no issues found)
- ✅ 2 rules skipped (not applicable to config)

---

### Common Log Patterns to Search For

#### **Search for Errors**

```bash
# Search all logs for errors
grep -r "Error" run-logs/ | head -20

# Search for warnings
grep -r "Warning" run-logs/

# Search for specific resource
grep -r "azurerm_api_management" run-logs/
```

#### **Extract Plan Summary**

```bash
# Get plan changes count
grep -E "Plan:|to add|to change|to destroy" run-logs/terraform/8_Terraform\ Plan.txt

# Output:
# Plan: 0 to add, 2 to change, 0 to destroy.
```

#### **Check for Azure Authentication Issues**

```bash
# View Azure login step
cat run-logs/terraform/8_Azure\ Login.txt

# Success indicator:
# "Successfully authenticated with Azure CLI"
```

---

### Analyzing Failed Jobs

#### **Identify the Failure**

```bash
# 1. Check job status
gh run view 5648394629

# Output shows:
# ✗ terraform job: FAILED
# └─ Step "Terraform Validate" failed

# 2. Download the failed logs
gh run download 5648394629 --dir failed_run

# 3. View the failed step
cat failed_run/terraform/6_Terraform\ Validate.txt
```

#### **Parse Error Messages**

```bash
# Extract validation errors
grep -A 5 "Error" failed_run/terraform/6_Terraform\ Validate.txt

# Example output:
# Error: Invalid resource configuration
# on main.tf line 42, in resource "azurerm_key_vault":
#   42: name = "MyPoC-KeyVault-2026"
# The name must be globally unique
```

---

## 5. Azure Log Analytics: Monitoring Deployment

### Prerequisites

Before running queries, gather your workspace information:

```bash
# Get Log Analytics workspace ID
az monitor log-analytics workspace list \
  --resource-group MyPoCRG \
  --query "[0].[id,name,resourceGroup]" \
  -o tsv

# Output:
# /subscriptions/xxx-xxx-xxx/resourcegroups/mypocrc/providers/microsoft.operationalinsights/workspaces/MyPoC-LogAnalytics
# MyPoC-LogAnalytics
# MyPoCRG
```

### Connecting to Log Analytics

#### **Option A: Azure Portal (GUI)**

1. Open Azure Portal: https://portal.azure.com
2. Search for "Log Analytics workspaces"
3. Click **"MyPoC-LogAnalytics"**
4. Click **"Logs"** (left sidebar, under Monitoring)
5. You'll see the query editor

#### **Option B: Azure CLI (CLI)**

```bash
# Query Log Analytics directly
az monitor log-analytics query \
  --workspace MyPoC-LogAnalytics \
  --analytics-query "AzureDiagnostics | limit 10"
```

#### **Option C: VS Code (IDE)**

Install Azure Log Analytics extension, then query directly in VS Code

---

### Query 1: Track Terraform Resource Provisioning

**Purpose**: See all Azure resources created/modified during pipeline deployment

```kql
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.APIMANAGEMENT" or ResourceProvider == "MICROSOFT.NETWORK"
| where OperationName contains "write" or OperationName contains "CREATE" or OperationName contains "UPDATE"
| project TimeGenerated, OperationName, ResourceType, Resource, ResultDescription
| order by TimeGenerated desc
| limit 100
```

**What to look for:**

- ✅ "CREATE" operations for new resources
- ✅ "UPDATE" operations for modified resources
- ⚠️ Any failed operations (ResultDescription contains "Failed")

**Example Output:**

```
TimeGenerated              Operation              Resource Type    Resource                Result
2026-04-20T14:35:22Z      CREATE APIService      APIMANAGEMENT    MyPoCAPIM              Succeeded
2026-04-20T14:33:15Z      CREATE AppGateway      NETWORK          MyPoC-AppGateway       Succeeded
2026-04-20T14:32:08Z      UPDATE KeyVault        KEYVAULT         mypoc-keyvault-001     Succeeded
```

---

### Query 2: Monitor APIM Deployment Status

**Purpose**: Verify APIM is deployed and responding to traffic

```kql
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.APIMANAGEMENT"
| where Category == "GatewayLogs" or Category == "GatewayRequests"
| project TimeGenerated, Category, httpMethod_s, urlPath_s, statusCode_s, totalTime_d
| summarize RequestCount=count(), AvgResponseTime=avg(totalTime_d), MaxResponseTime=max(totalTime_d) 
            by bin(TimeGenerated, 5m), statusCode_s
| order by TimeGenerated desc
| limit 50
```

**What to look for:**

- ✅ statusCode_s = "200" (requests succeeding)
- ⚠️ statusCode_s = "5xx" (server errors)
- ⚠️ High AvgResponseTime (>1000ms)

**Example Output:**

```
TimeGenerated              StatusCode  RequestCount  AvgResponseTime  MaxResponseTime
2026-04-20T14:45:00Z      200         45            425.3            892.1
2026-04-20T14:40:00Z      200         38            398.7            645.2
2026-04-20T14:35:00Z      200         52            412.1            756.8
```

---

### Query 3: Review Security & Access Events

**Purpose**: Track who accessed what and when (security audit)

```kql
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.KEYVAULT"
| where OperationName != "authenticate"
| project TimeGenerated, OperationName, identity_claim_appid_s, clientIP_s, httpStatusCode_d, Resource
| order by TimeGenerated desc
| limit 100
```

**What to look for:**

- ✅ httpStatusCode_d = 200 (successful operations)
- ⚠️ httpStatusCode_d = 401/403 (authentication/permission failures)
- ⚠️ Unusual IP addresses in clientIP_s

**Example Output:**

```
TimeGenerated              Operation         AppID              ClientIP        Status  Resource
2026-04-20T14:35:22Z      SecretGet         app-id-123         168.61.54.72    200     api-backend-secret
2026-04-20T14:34:15Z      SecretSet         terraform-sp       10.0.1.10       200     new-secret
2026-04-20T14:33:08Z      VaultUpdate       user@company.com   203.0.113.45    200     KeyVault config
```

---

### Query 4: Identify Failed Deployments

**Purpose**: Find failed operations during deployment

```kql
AzureDiagnostics
| where ResultDescription contains "Failed" or ResultDescription contains "Error" or statusCode_s startswith "5"
| project TimeGenerated, OperationName, ResourceType, Resource, ResultDescription, statusCode_s
| order by TimeGenerated desc
| limit 50
```

**What to look for:**

- ⚠️ Any ResultDescription containing "Failed"
- ⚠️ statusCode_s in 5xx range (server errors)
- ⚠️ Connection timeouts or throttling errors

**Example Output:**

```
TimeGenerated              Operation              ResourceType    Status Code  Error
2026-04-20T14:28:15Z      ApplyAPIMPolicy        APIMANAGEMENT   500          Throttling limit exceeded
2026-04-20T14:27:08Z      UpdateKeyVault         KEYVAULT        403          Insufficient permissions
```

---

### Query 5: Performance Metrics by Resource

**Purpose**: Monitor response times and latency for each component

```kql
AzureDiagnostics
| where Category == "GatewayRequests" or Category == "ApplicationGatewayAccessLog"
| project TimeGenerated, Resource, totalTime_d, timeTaken_d, httpMethod_s, urlPath_s, statusCode_s
| summarize AvgLatency=avg(totalTime_d), P95Latency=percentile(totalTime_d, 95), P99Latency=percentile(totalTime_d, 99), MaxLatency=max(totalTime_d), RequestCount=count()
            by bin(TimeGenerated, 1m), Resource
| order by TimeGenerated desc
| limit 100
```

**What to look for:**

- ✅ AvgLatency < 500ms (good performance)
- ⚠️ P99Latency > 1000ms (occasional slowness)
- ⚠️ MaxLatency > 5000ms (potential issues)

**Example Output:**

```
TimeGenerated         Resource              AvgLatency  P95Latency  P99Latency  MaxLatency  RequestCount
2026-04-20T14:45:00Z  MyPoCAPIM             425.3       612.1       845.3       1234.5      152
2026-04-20T14:44:00Z  MyPoC-AppGateway      198.7       245.2       398.1       512.3       189
```

---

### Query 6: WAF & Security Rule Triggers

**Purpose**: Monitor Web Application Firewall activity and blocked requests

```kql
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.NETWORK"
| where Category == "ApplicationGatewayFirewallLog"
| project TimeGenerated, clientIP_s, action_s, Message, ruleSetType_s, ruleSetVersion_s
| where action_s == "Blocked"
| summarize BlockCount=count() by clientIP_s, action_s, ruleSetType_s
| order by BlockCount desc
| limit 50
```

**What to look for:**

- ✅ Few or zero blocks (proper WAF tuning)
- ⚠️ High BlockCount from single IP (potential attack)
- ⚠️ Blocks from your own IP (misconfiguration)

**Example Output:**

```
TimeGenerated         ClientIP            Action   RuleSet    BlockCount
2026-04-20T14:45:22Z  192.0.2.100         Blocked  OWASP 3.2  1
2026-04-20T14:35:15Z  198.51.100.50       Blocked  OWASP 3.2  3
```

---

### Query 7: Diagnostic Settings Configuration

**Purpose**: Verify diagnostic logs are properly configured for all resources

```kql
AzureDiagnostics
| where isnotempty(DiagnosticSettings_s)
| project TimeGenerated, Resource, ResourceType, Category, LogAnalyticsWorkspaceId_s
| distinct Resource, ResourceType, Category
| order by Resource
```

**What to look for:**

- ✅ All critical resources logged (APIM, App Gateway, Key Vault)
- ✅ Expected categories appearing (GatewayLogs, AccessLogs, AuditLogs)
- ⚠️ Missing resources (may indicate diagnostic settings not enabled)

**Example Output:**

```
Resource              ResourceType           Category                  WorkspaceID
MyPoCAPIM             APIMANAGEMENT          GatewayLogs              /subscriptions/.../MyPoC-LogAnalytics
MyPoCAPIM             APIMANAGEMENT          GatewayRequests          /subscriptions/.../MyPoC-LogAnalytics
MyPoC-AppGateway      APPLICATIONGATEWAYS    ApplicationGatewayAccessLog
mypoc-keyvault-001    VAULTS                 AuditEvent
```

---

### Query 8: End-to-End Deployment Timeline

**Purpose**: Correlate GitHub Actions pipeline run with Azure resource deployment

```kql
AzureDiagnostics
| where OperationName contains "CREATE" or OperationName contains "UPDATE" or OperationName contains "DELETE"
| project TimeGenerated, OperationName, Resource, ResourceType, ResultDescription, CallerIP_s=clientIP_s
| extend ResourceGroup=extract(@"resourcegroups/([^/]+)", 1, tolower(Resource))
| where ResourceGroup =~ "MyPoCRG"
| summarize TimeSpan=max(TimeGenerated)-min(TimeGenerated), EventCount=count(), FirstEvent=min(TimeGenerated), LastEvent=max(TimeGenerated)
            by ResourceType
| order by FirstEvent
```

**What to look for:**

- ✅ TimeSpan should match pipeline duration (~15-20 min)
- ✅ Multiple ResourceTypes being created/updated
- ✅ FirstEvent matches GitHub Actions job start time

**Example Output:**

```
ResourceType             EventCount  TimeSpan         FirstEvent              LastEvent
APIMANAGEMENT           5           6m 45s          2026-04-20T14:32:15Z    2026-04-20T14:39:00Z
APPLICATIONGATEWAYS     3           4m 12s          2026-04-20T14:32:30Z    2026-04-20T14:36:42Z
VAULTS                  2           2m 08s          2026-04-20T14:35:10Z    2026-04-20T14:37:18Z
```

---

### Running Queries in Log Analytics

#### **Using Azure Portal**

1. Open Log Analytics workspace: MyPoC-LogAnalytics
2. Click **"Logs"** (left sidebar)
3. Paste query into editor
4. Click **"Run"** (blue button)
5. Results appear below

**Tips:**

- Use **"Time range"** selector (top right) to change date range
- Click **"Save"** to save frequently-used queries
- Use **"Export"** to export results to CSV

#### **Using Azure CLI**

```bash
# Run query and get JSON output
az monitor log-analytics query \
  --workspace MyPoC-LogAnalytics \
  --analytics-query "AzureDiagnostics | where ResourceProvider == 'MICROSOFT.APIMANAGEMENT' | limit 10" \
  --output json | jq '.tables[0].rows'
```

#### **Using PowerShell**

```powershell
# Query Log Analytics with PowerShell
$query = @"
AzureDiagnostics
| where ResourceProvider == 'MICROSOFT.APIMANAGEMENT'
| where statusCode_s == '200'
| summarize Count=count() by bin(TimeGenerated, 5m)
"@

az monitor log-analytics query \
  --workspace MyPoC-LogAnalytics \
  --analytics-query $query \
  --output table
```

---

### Creating Custom Dashboards

#### **Pin Query Results to Dashboard**

1. Run a query in Log Analytics
2. Click **"Pin to dashboard"** (top right)
3. Select or create dashboard
4. Click **"Pin"**

#### **Create Alert from Query**

1. Run a query
2. Click **"+ New alert rule"**
3. Configure threshold (e.g., if RequestCount > 1000)
4. Set notification (email, webhook, etc.)
5. Click **"Create alert rule"**

---

## 6. End-to-End Troubleshooting

### Workflow Execution Troubleshooting

#### **Pipeline Doesn't Trigger on Push**

**Check:**

1. **Branch protection rules**
   - GitHub > Settings > Branches > main > Require branches to be up to date
   - Check if status checks are blocking merge

2. **Workflow file syntax**
   ```bash
   # Validate workflow YAML
   gh workflow list
   # Should show: terraform-ci-cd.yml
   ```

3. **Repository secrets**
   - GitHub > Settings > Secrets and variables > Actions
   - Verify AZURE_CREDENTIALS secret exists
   - Secrets are encrypted; you can't view them, but you can verify they exist

**Fix:**

```bash
# Re-authenticate Azure credentials
az ad sp create-for-rbac --name "github-actions-sp" --role Contributor

# Update GitHub secret with new credentials
gh secret set AZURE_CREDENTIALS --body '{"clientId":"...","clientSecret":"...","subscriptionId":"...","tenantId":"..."}'
```

---

#### **Pipeline Hangs or Timeout**

**Symptoms:**

- Pipeline running for >60 minutes
- No output for 10+ minutes

**Check:**

```bash
# Download and inspect logs
gh run download <RUN_ID> --dir logs

# Look for stuck step
grep -n "⏳\|running\|timeout" logs/terraform/*.txt

# Check specific step
cat logs/terraform/8_Terraform\ Apply.txt | tail -50
```

**Common Causes:**

1. **Azure resource timeout** (APIM deployment takes 15+ min)
   - Solution: Increase timeout or use `-target` to deploy sequentially

2. **Terraform state lock** (another pipeline running)
   - Solution: Unlock or use `-lock=false`

3. **Network connectivity** (Azure unreachable)
   - Solution: Check firewall/NSG rules, retry pipeline

**Fix:**

```bash
# Force unlock state
terraform force-unlock <LOCK_ID>

# Or use -lock=false
terraform apply -auto-approve -lock=false
```

---

### Deployment Failures

#### **Terraform Validate Fails (tfsec Issues)**

**Log Output:**

```
Terraform Static Analysis (tfsec)
──────────────────────────────────
tests run: 142
passed: 140
failed: 2

Failed checks:
1. aws-s3-enable-bucket-encryption [ERROR]
2. azure-appgw-enable-waf [ERROR]
```

**Check:**

1. Review tfsec failures
2. Update Terraform code or suppress false positives

**Fix:**

```hcl
# In main.tf, add tfsec suppression comment:
resource "azurerm_storage_account" "example" {
  # tfsec:skip=aws-s3-enable-bucket-encryption:Skip encryption for dev env
  encrypted = false
}
```

Then re-run pipeline:

```bash
git add main.tf
git commit -m "fix: address tfsec security issues"
git push origin main
```

---

#### **Terraform Plan Shows Unwanted Changes**

**Log Output:**

```
Plan: 3 to add, 2 to change, 1 to destroy
```

**Check:**

1. Are these planned changes correct?
2. Did something change in Azure outside of Terraform?

**Fix:**

```bash
# Refresh state from Azure
terraform refresh

# Review proposed changes
terraform plan | grep -E "will be|changed"

# If changes are wrong, investigate:
az resource list --resource-group MyPoCRG --output table
```

---

#### **Terraform Apply Fails: Permission Denied**

**Log Output:**

```
Error: Insufficient permissions
on main.tf line 45, in resource "azurerm_key_vault":
  Details: Caller does not have permission for action
```

**Check:**

1. Azure credentials in AZURE_CREDENTIALS secret
2. Service principal permissions

**Fix:**

```bash
# Get current service principal
az account show

# Grant required permissions
az role assignment create \
  --assignee <CLIENT_ID> \
  --role "Contributor" \
  --scope /subscriptions/<SUBSCRIPTION_ID>

# Update GitHub secret
gh secret set AZURE_CREDENTIALS --body '...new credentials...'
```

---

#### **Terraform Apply Fails: Resource Already Exists**

**Log Output:**

```
Error: A resource with the ID `/subscriptions/.../providers/Microsoft.ApiManagement/service/MyPoCAPIM` already exists
```

**Check:**

1. Resource exists in Azure but not in Terraform state

**Fix:**

```bash
# Import existing resource into state
terraform import azurerm_api_management.poc_apim \
  /subscriptions/YOUR_SUB_ID/resourceGroups/MyPoCRG/providers/Microsoft.ApiManagement/service/MyPoCAPIM

# Verify state
terraform state show azurerm_api_management.poc_apim
```

---

### Monitoring & Observability Issues

#### **No Logs Appearing in Log Analytics**

**Check:**

1. Diagnostic settings configured
2. Logs are flowing

```bash
# List diagnostic settings
az monitor diagnostic-settings list --resource /subscriptions/.../resourceGroups/MyPoCRG/providers/Microsoft.ApiManagement/service/MyPoCAPIM

# Should show: logs enabled, workspace destination configured
```

**Fix:**

```bash
# Re-create diagnostic settings
az monitor diagnostic-settings create \
  --resource MyPoCAPIM \
  --resource-group MyPoCRG \
  --name "send-to-loganalytics" \
  --workspace /subscriptions/.../workspaces/MyPoC-LogAnalytics \
  --logs '[{"category":"GatewayLogs","enabled":true},{"category":"GatewayRequests","enabled":true}]'
```

---

#### **KQL Query Returns No Results**

**Check:**

1. Correct workspace name
2. Correct time range
3. Resources deployed and operational

**Fix:**

```kql
# Simple test query - should always return something
AzureDiagnostics
| distinct ResourceProvider
| limit 10

# If no results, check time range:
// Set time range in query
AzureDiagnostics
| where TimeGenerated > ago(7d)
| limit 10
```

---

### API Performance Issues

#### **API Calls Slow (>2000ms)**

**Check:**

1. Application Gateway health
2. APIM throttling policies
3. Backend service performance

```bash
# View APIM throttling policies
az apim api policy show \
  --service-name MyPoCAPIM \
  --resource-group MyPoCRG \
  --api-id mybasicapi \
  -o yaml

# Check Application Gateway performance
az network application-gateway show \
  --name MyPoC-AppGateway \
  --resource-group MyPoCRG \
  --query "operationalState"
```

**Query Log Analytics:**

```kql
AzureDiagnostics
| where totalTime_d > 2000
| project TimeGenerated, Resource, totalTime_d, urlPath_s, httpMethod_s
| order by TimeGenerated desc
| limit 100
```

---

### Security & Access Issues

#### **Can't Access APIM Gateway**

**Check:**

1. Public IP whitelisting
2. WAF not blocking requests
3. APIM is running

```bash
# Verify firewall allows your IP
curl -v https://mypocapim.azure-api.net/api/get

# Check WAF logs
az monitor log-analytics query \
  --workspace MyPoC-LogAnalytics \
  --analytics-query "AzureDiagnostics | where Category == 'ApplicationGatewayFirewallLog' | where action_s == 'Blocked'"
```

**Fix (if IP is blocked by WAF):**

1. Add your IP to WAF bypass rule
2. Or switch WAF to "Detection" mode

```bash
az network application-gateway waf-policy update \
  --name MyPoC-WAFPolicy \
  --resource-group MyPoCRG \
  --set properties.managedRules.exclusions[]='{"matchVariable":"GeoLocation","selectorMatchOperator":"Equals","selector":"US"}'
```

---

### Getting Help

#### **Collect Diagnostic Information**

When reporting issues, gather this information:

```powershell
# Collect diagnostic bundle
$bundle = @{
    "gh_run_id" = "5648394629"
    "terraform_version" = terraform version | Select-Object -Last 1
    "azure_cli_version" = az version
    "logs" = @()
}

# Download GitHub Actions logs
gh run download 5648394629 --dir ./github_logs

# Download Azure resource state
terraform state list | ForEach-Object {
    $bundle.logs += "=== $_ ===" 
    $bundle.logs += (terraform state show $_)
}

# Export summary
$bundle | ConvertTo-Json | Out-File diagnostic_bundle.json
Write-Host "Diagnostic bundle saved: diagnostic_bundle.json"
```

---

## Quick Reference: Command Cheatsheet

### GitHub Actions

```bash
# List workflows
gh workflow list

# List runs for a workflow
gh run list --workflow=terraform-ci-cd.yml --limit 10

# View specific run
gh run view <RUN_ID>

# Download run logs
gh run download <RUN_ID> --dir ./logs

# Re-run failed jobs
gh run rerun <RUN_ID>

# View real-time logs
gh run watch <RUN_ID>
```

### Terraform

```bash
# Initialize
terraform init

# Validate
terraform validate

# Format check
terraform fmt -check -recursive

# Plan
terraform plan -out=tfplan

# Apply
terraform apply -auto-approve -lock=false

# Destroy
terraform destroy -auto-approve
```

### Azure Log Analytics

```bash
# Query workspace
az monitor log-analytics query --workspace MyPoC-LogAnalytics --analytics-query "AzureDiagnostics | limit 10"

# List workspaces
az monitor log-analytics workspace list --resource-group MyPoCRG

# Export query results
az monitor log-analytics query --workspace MyPoC-LogAnalytics --analytics-query "AzureDiagnostics | limit 10" --output json | ConvertFrom-Json
```

### Azure Resources

```bash
# List all resources in group
az resource list --resource-group MyPoCRG --output table

# Get APIM details
az apim show --name MyPoCAPIM --resource-group MyPoCRG

# View diagnostic settings
az monitor diagnostic-settings list --resource /subscriptions/.../providers/Microsoft.ApiManagement/service/MyPoCAPIM

# Check resource deployment status
az deployment group list --resource-group MyPoCRG --output table
```

---

## Summary

**You've learned:**

1. ✅ How to trigger pipeline (push/PR/manual)
2. ✅ How to monitor real-time execution in GitHub Actions UI
3. ✅ How to capture and download artifacts
4. ✅ How to retrieve logs via GitHub CLI
5. ✅ How to run 8 pre-built KQL queries in Log Analytics
6. ✅ How to correlate GitHub Actions with Azure deployments
7. ✅ How to troubleshoot common failures
8. ✅ How to diagnose performance issues

**Next Steps:**

- [ ] Save this guide as your reference
- [ ] Bookmark your GitHub Actions page: `https://github.com/YOUR_ORG/YOUR_REPO/actions`
- [ ] Bookmark your Log Analytics workspace: Azure Portal > Log Analytics Workspaces > MyPoC-LogAnalytics
- [ ] Configure GitHub CLI (`gh auth login`)
- [ ] Test a pipeline run and review all logs
- [ ] Practice running KQL queries

---

**Questions?** Refer to the troubleshooting section or check Azure/GitHub documentation links in main README.md.
