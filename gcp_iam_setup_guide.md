# GCP Project Setup and IAM Configuration Guide

A comprehensive hands-on tutorial for creating a new Google Cloud Platform project and configuring Identity and Access Management (IAM).

---

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Part 1: Creating a GCP Free Tier Account](#part-1-creating-a-gcp-free-tier-account)
3. [Part 2: Creating a New Project](#part-2-creating-a-new-project)
4. [Part 3: Setting Up Billing](#part-3-setting-up-billing)
5. [Part 4: IAM Configuration](#part-4-iam-configuration)
6. [Part 5: Creating Custom IAM Roles](#part-5-creating-custom-iam-roles)
7. [Part 6: Service Accounts](#part-6-service-accounts)
8. [Part 7: User Management](#part-7-user-management)
9. [Part 8: Organization-Level Policies](#part-8-organization-level-policies)
10. [Part 9: Testing and Verification](#part-9-testing-and-verification)
11. [Common Issues and Troubleshooting](#common-issues-and-troubleshooting)
12. [Security Best Practices](#security-best-practices)

---

## Prerequisites

Before starting, ensure you have:
- A valid Google account (Gmail or Google Workspace)
- A valid credit/debit card for verification (you won't be charged during free tier)
- Basic understanding of cloud computing concepts
- A web browser (Chrome recommended)

---

## Part 1: Creating a GCP Free Tier Account

### Step 1: Sign Up for GCP

1. Navigate to [cloud.google.com/free](https://cloud.google.com/free)
2. Click **"Get started for free"**
3. Sign in with your Google account
4. Select your country and accept the Terms of Service
5. Click **"Continue"**

### Step 2: Account Verification

1. Choose **Account type**: Individual or Business
2. Enter your billing information:
   - Name and address
   - Credit/debit card details (for verification only)
3. Complete the verification process
4. Click **"Start my free trial"**

**Note**: The free tier includes:
- $300 credit valid for 90 days
- Always Free tier products (limited usage)
- No automatic charges after trial ends

---

## Part 2: Creating a New Project

### Method 1: Via GCP Console (Web UI)

1. Navigate to [console.cloud.google.com](https://console.cloud.google.com)
2. Click the **project dropdown** at the top of the page
3. Click **"New Project"** in the dialog
4. Fill in the project details:
   - **Project name**: `my-first-gcp-project` (choose a meaningful name)
   - **Project ID**: Auto-generated or customize (must be globally unique)
   - **Organization**: Select if applicable (otherwise "No organization")
   - **Location**: Choose folder or organization (if available)
5. Click **"Create"**
6. Wait for the project to be created (usually takes 10-30 seconds)

### Method 2: Via gcloud CLI

```bash
# Install gcloud CLI if not already installed
# Visit: cloud.google.com/sdk/docs/install

# Initialize gcloud
gcloud init

# Create a new project
gcloud projects create my-first-gcp-project --name="My First GCP Project"

# Set the new project as active
gcloud config set project my-first-gcp-project
```

### Verify Project Creation

```bash
# List all projects
gcloud projects list

# Get current project details
gcloud projects describe my-first-gcp-project
```

---

## Part 3: Setting Up Billing

### Link Billing Account to Project

1. Navigate to **"Billing"** from the hamburger menu (☰)
2. If you have a billing account:
   - Click **"Link a billing account"**
   - Select your billing account
   - Click **"Set account"**
3. If you need to create a billing account:
   - Click **"Create account"**
   - Follow the prompts to set up billing

### Via gcloud CLI

```bash
# List billing accounts
gcloud billing accounts list

# Link billing account to project
gcloud billing projects link my-first-gcp-project \
  --billing-account=BILLING_ACCOUNT_ID
```

### Set Up Budget Alerts (Recommended)

1. Go to **Billing** → **Budgets & alerts**
2. Click **"Create budget"**
3. Configure:
   - **Projects**: Select your project
   - **Budget amount**: Set a threshold (e.g., $50)
   - **Threshold rules**: 50%, 90%, 100%
   - **Email notifications**: Add your email
4. Click **"Finish"**

---

## Part 4: IAM Configuration

### Understanding IAM Basics

**IAM Components**:
- **Members**: Who (users, groups, service accounts, domains)
- **Roles**: What permissions (predefined or custom)
- **Policies**: Bindings of members to roles on resources

**Role Types**:
- **Primitive Roles**: Owner, Editor, Viewer (broad permissions)
- **Predefined Roles**: Granular, service-specific roles
- **Custom Roles**: User-defined roles with specific permissions

### Navigate to IAM

1. Open the GCP Console
2. Select your project
3. Navigate to **IAM & Admin** → **IAM**

---

## Part 5: Creating Custom IAM Roles

### Scenario: Create a Custom Storage Administrator Role

#### Via GCP Console

1. Go to **IAM & Admin** → **Roles**
2. Click **"Create Role"**
3. Fill in details:
   - **Title**: `Custom Storage Admin`
   - **Description**: `Custom role for storage administration`
   - **ID**: `customStorageAdmin`
   - **Role launch stage**: General Availability
4. Click **"Add Permissions"**
5. Filter and select permissions:
   ```
   storage.buckets.create
   storage.buckets.delete
   storage.buckets.get
   storage.buckets.list
   storage.objects.create
   storage.objects.delete
   storage.objects.get
   storage.objects.list
   ```
6. Click **"Create"**

#### Via gcloud CLI

```bash
# Create a YAML file for the custom role
cat > custom-storage-admin.yaml <<EOF
title: "Custom Storage Admin"
description: "Custom role for storage administration"
stage: "GA"
includedPermissions:
- storage.buckets.create
- storage.buckets.delete
- storage.buckets.get
- storage.buckets.list
- storage.objects.create
- storage.objects.delete
- storage.objects.get
- storage.objects.list
EOF

# Create the custom role
gcloud iam roles create customStorageAdmin \
  --project=my-first-gcp-project \
  --file=custom-storage-admin.yaml

# Verify creation
gcloud iam roles describe customStorageAdmin \
  --project=my-first-gcp-project
```

### Update Custom Role

```bash
# Add additional permissions
gcloud iam roles update customStorageAdmin \
  --project=my-first-gcp-project \
  --add-permissions=storage.buckets.update

# Remove permissions
gcloud iam roles update customStorageAdmin \
  --project=my-first-gcp-project \
  --remove-permissions=storage.buckets.delete
```

---

## Part 6: Service Accounts

### Create a Service Account for an Application

#### Scenario: Application Service Account

**Use Case**: Create a service account for a web application that needs to access Cloud Storage.

#### Via GCP Console

1. Navigate to **IAM & Admin** → **Service Accounts**
2. Click **"Create Service Account"**
3. Fill in details:
   - **Service account name**: `webapp-storage-sa`
   - **Service account ID**: Auto-generated
   - **Description**: `Service account for web application storage access`
4. Click **"Create and Continue"**
5. Grant roles:
   - Click **"Select a role"**
   - Choose **Storage Object Viewer** for read access
   - Or **Storage Object Admin** for read/write access
   - Click **"Continue"**
6. Grant users access (optional):
   - Add users who can impersonate this service account
   - Click **"Done"**

#### Via gcloud CLI

```bash
# Create service account
gcloud iam service-accounts create webapp-storage-sa \
  --description="Service account for web application storage access" \
  --display-name="Web App Storage Service Account"

# Assign role to service account
gcloud projects add-iam-policy-binding my-first-gcp-project \
  --member="serviceAccount:webapp-storage-sa@my-first-gcp-project.iam.gserviceaccount.com" \
  --role="roles/storage.objectViewer"

# List service accounts
gcloud iam service-accounts list
```

### Generate Service Account Keys

#### Via GCP Console

1. Go to **Service Accounts** page
2. Click on the service account (`webapp-storage-sa`)
3. Navigate to **"Keys"** tab
4. Click **"Add Key"** → **"Create new key"**
5. Select **JSON** format
6. Click **"Create"**
7. The key file downloads automatically (keep it secure!)

#### Via gcloud CLI

```bash
# Create and download key
gcloud iam service-accounts keys create ~/webapp-sa-key.json \
  --iam-account=webapp-storage-sa@my-first-gcp-project.iam.gserviceaccount.com

# List keys
gcloud iam service-accounts keys list \
  --iam-account=webapp-storage-sa@my-first-gcp-project.iam.gserviceaccount.com
```

**Security Warning**: Service account keys are sensitive! Store them securely and never commit to version control.

### Best Practice: Use Workload Identity Instead

For applications running on GCP (GKE, Cloud Run, Compute Engine):

```bash
# Enable Workload Identity on GKE cluster
gcloud container clusters update my-cluster \
  --workload-pool=my-first-gcp-project.svc.id.goog

# Bind Kubernetes SA to GCP SA
gcloud iam service-accounts add-iam-policy-binding \
  webapp-storage-sa@my-first-gcp-project.iam.gserviceaccount.com \
  --role=roles/iam.workloadIdentityUser \
  --member="serviceAccount:my-first-gcp-project.svc.id.goog[namespace/ksa-name]"
```

---

## Part 7: User Management

### Add Users to Your Project

#### Scenario: Add Team Members

**User Types**:
- **Developer**: Editor role
- **Data Analyst**: BigQuery Data Viewer
- **External Auditor**: Viewer role

#### Via GCP Console

1. Navigate to **IAM & Admin** → **IAM**
2. Click **"Grant Access"**
3. Add new principals:
   - **New principals**: Enter email address (e.g., `developer@example.com`)
   - **Select a role**: Choose appropriate role
     - For developer: **Editor**
     - For analyst: **BigQuery Data Viewer**
     - For auditor: **Viewer**
4. Add conditions (optional):
   - Expiration time
   - IP address restrictions
5. Click **"Save"**

#### Via gcloud CLI

```bash
# Add developer with Editor role
gcloud projects add-iam-policy-binding my-first-gcp-project \
  --member="user:developer@example.com" \
  --role="roles/editor"

# Add analyst with BigQuery Data Viewer role
gcloud projects add-iam-policy-binding my-first-gcp-project \
  --member="user:analyst@example.com" \
  --role="roles/bigquery.dataViewer"

# Add auditor with Viewer role
gcloud projects add-iam-policy-binding my-first-gcp-project \
  --member="user:auditor@example.com" \
  --role="roles/viewer"

# Add group
gcloud projects add-iam-policy-binding my-first-gcp-project \
  --member="group:engineering@example.com" \
  --role="roles/compute.instanceAdmin.v1"
```

### Add Conditional Access

```bash
# Grant access that expires
gcloud projects add-iam-policy-binding my-first-gcp-project \
  --member="user:contractor@example.com" \
  --role="roles/viewer" \
  --condition='expression=request.time < timestamp("2024-12-31T23:59:59Z"),title=expires_end_of_2024'
```

### Remove User Access

```bash
# Remove user access
gcloud projects remove-iam-policy-binding my-first-gcp-project \
  --member="user:developer@example.com" \
  --role="roles/editor"
```

---

## Part 8: Organization-Level Policies

**Note**: Organization-level policies require a Google Workspace or Cloud Identity account.

### Setting Up Organization Policies

#### Access Organization Policies

1. Navigate to **IAM & Admin** → **Organization Policies**
2. Select policy to configure

#### Common Organization Policies

**1. Restrict Resource Locations**

```bash
# Restrict to specific regions (e.g., US only)
gcloud resource-manager org-policies set-policy \
  --organization=ORGANIZATION_ID \
  policy.yaml
```

policy.yaml:
```yaml
constraint: constraints/gcp.resourceLocations
listPolicy:
  allowedValues:
    - in:us-locations
```

**2. Disable Service Account Key Creation**

```bash
# Prevent service account key creation
cat > disable-sa-keys.yaml <<EOF
constraint: constraints/iam.disableServiceAccountKeyCreation
booleanPolicy:
  enforced: true
EOF

gcloud resource-manager org-policies set-policy \
  --organization=ORGANIZATION_ID \
  disable-sa-keys.yaml
```

**3. Enforce Uniform Bucket-Level Access**

```bash
cat > uniform-bucket-access.yaml <<EOF
constraint: constraints/storage.uniformBucketLevelAccess
booleanPolicy:
  enforced: true
EOF

gcloud resource-manager org-policies set-policy \
  --project=my-first-gcp-project \
  uniform-bucket-access.yaml
```

### View Current Policies

```bash
# List all organization policies
gcloud resource-manager org-policies list \
  --organization=ORGANIZATION_ID

# Describe specific policy
gcloud resource-manager org-policies describe \
  constraints/iam.disableServiceAccountKeyCreation \
  --organization=ORGANIZATION_ID
```

---

## Part 9: Testing and Verification

### Test 1: Verify Service Account Access

**Create a test Cloud Storage bucket**:

```bash
# Create bucket
gsutil mb gs://my-test-bucket-unique-name-12345

# Upload test file
echo "Test content" > test.txt
gsutil cp test.txt gs://my-test-bucket-unique-name-12345/

# Authenticate as service account
gcloud auth activate-service-account \
  --key-file=~/webapp-sa-key.json

# Test read access
gsutil ls gs://my-test-bucket-unique-name-12345/

# Test download
gsutil cp gs://my-test-bucket-unique-name-12345/test.txt downloaded.txt

# Switch back to user account
gcloud config set account your-email@gmail.com
```

### Test 2: Verify User Permissions

**Invite test user**:

1. Add user with Viewer role
2. Ask them to log in to GCP Console
3. Verify they can:
   - View resources
   - NOT create/modify resources
4. Check audit logs for their activity

```bash
# View audit logs
gcloud logging read "protoPayload.authenticationInfo.principalEmail=viewer@example.com" \
  --limit 10 \
  --format json
```

### Test 3: Custom Role Verification

```bash
# Get IAM policy
gcloud projects get-iam-policy my-first-gcp-project \
  --format=json > policy.json

# Search for custom role
cat policy.json | jq '.bindings[] | select(.role=="projects/my-first-gcp-project/roles/customStorageAdmin")'
```

### Test 4: Policy Simulator

1. Navigate to **IAM & Admin** → **Policy Troubleshooter**
2. Enter:
   - **Member**: Service account or user email
   - **Resource**: Full resource name (e.g., `//storage.googleapis.com/my-bucket`)
   - **Permission**: Specific permission to test
3. Click **"Check access"**
4. Review results showing why access is granted/denied

---

## Common Issues and Troubleshooting

### Issue 1: "Permission Denied" Errors

**Problem**: User/service account cannot access resources

**Diagnosis**:
```bash
# Check current permissions
gcloud projects get-iam-policy my-first-gcp-project \
  --flatten="bindings[].members" \
  --format="table(bindings.role)" \
  --filter="bindings.members:serviceAccount:webapp-storage-sa@*"
```

**Solutions**:
1. Verify role assignment is correct
2. Check if API is enabled:
   ```bash
   gcloud services list --enabled
   ```
3. Enable required API:
   ```bash
   gcloud services enable storage.googleapis.com
   ```
4. Wait for IAM propagation (can take up to 80 seconds)

### Issue 2: Service Account Key Not Working

**Problem**: Authentication fails with service account key

**Diagnosis**:
```bash
# Verify key is valid
gcloud iam service-accounts keys list \
  --iam-account=webapp-storage-sa@my-first-gcp-project.iam.gserviceaccount.com

# Check key expiration
cat ~/webapp-sa-key.json | jq -r '.private_key_id'
```

**Solutions**:
1. Ensure JSON key file is not corrupted
2. Check file permissions (should not be world-readable)
3. Verify service account is not disabled
4. Generate new key if needed

### Issue 3: Billing Not Linked

**Problem**: Cannot create resources due to billing issues

**Diagnosis**:
```bash
# Check billing status
gcloud billing projects describe my-first-gcp-project
```

**Solutions**:
1. Link billing account to project
2. Verify billing account is active
3. Check free tier credits haven't expired

### Issue 4: IAM Changes Not Taking Effect

**Problem**: Permission changes don't seem to work

**Reasons**:
- IAM propagation delay (up to 80 seconds)
- Cached credentials
- Organization policy override

**Solutions**:
```bash
# Force credential refresh
gcloud auth application-default revoke
gcloud auth application-default login

# Wait and retry
sleep 90

# Check for organization policy conflicts
gcloud resource-manager org-policies describe \
  constraints/iam.allowedPolicyMemberDomains \
  --project=my-first-gcp-project
```

### Issue 5: Cannot Create Custom Role

**Problem**: Custom role creation fails

**Common Causes**:
1. Missing permissions (need `iam.roles.create`)
2. Invalid permission names
3. Role ID conflicts

**Solutions**:
```bash
# Verify you have permission
gcloud projects get-iam-policy my-first-gcp-project \
  --flatten="bindings[].members" \
  --filter="bindings.members:user:$(gcloud config get-value account)"

# Test permissions
gcloud iam roles testable-permissions \
  //cloudresourcemanager.googleapis.com/projects/my-first-gcp-project

# List available permissions for a service
gcloud iam list-testable-permissions \
  //storage.googleapis.com
```

### Issue 6: Quota Exceeded Errors

**Problem**: "Quota exceeded" when creating resources

**Solutions**:
```bash
# Check quotas
gcloud compute project-info describe --project=my-first-gcp-project

# Request quota increase via Console:
# IAM & Admin → Quotas → Select quota → Request increase
```

---

## Security Best Practices

### 1. Principle of Least Privilege

**Always grant the minimum permissions necessary**:

```bash
# Bad: Granting Owner role
gcloud projects add-iam-policy-binding my-first-gcp-project \
  --member="user:developer@example.com" \
  --role="roles/owner"

# Good: Grant specific role
gcloud projects add-iam-policy-binding my-first-gcp-project \
  --member="user:developer@example.com" \
  --role="roles/compute.instanceAdmin.v1"
```

### 2. Avoid Primitive Roles

**Use predefined or custom roles instead of Owner/Editor/Viewer**:

- ❌ `roles/owner`
- ❌ `roles/editor`
- ✅ `roles/storage.objectAdmin`
- ✅ `roles/compute.instanceAdmin.v1`

### 3. Service Account Key Management

**Best Practices**:
```bash
# Rotate keys regularly (every 90 days)
# Delete old keys
gcloud iam service-accounts keys delete KEY_ID \
  --iam-account=webapp-storage-sa@my-first-gcp-project.iam.gserviceaccount.com

# Use key rotation script
for key in $(gcloud iam service-accounts keys list \
  --iam-account=SA_EMAIL \
  --filter="validAfterTime<'-90d'" \
  --format="value(name)"); do
  gcloud iam service-accounts keys delete $key \
    --iam-account=SA_EMAIL --quiet
done
```

### 4. Enable Audit Logging

```bash
# Enable Data Access audit logs (be mindful of costs)
cat > audit-config.yaml <<EOF
auditConfigs:
- auditLogConfigs:
  - logType: ADMIN_READ
  - logType: DATA_READ
  - logType: DATA_WRITE
  service: allServices
EOF

gcloud projects set-iam-policy my-first-gcp-project audit-config.yaml
```

### 5. Use Groups for Access Management

**Create groups instead of assigning individual users**:

```bash
# Add group instead of individual users
gcloud projects add-iam-policy-binding my-first-gcp-project \
  --member="group:developers@example.com" \
  --role="roles/editor"
```

### 6. Implement Resource Hierarchy

**Project Structure**:
```
Organization
├── Folder: Production
│   └── Project: prod-app
├── Folder: Development
│   └── Project: dev-app
└── Folder: Shared Services
    └── Project: shared-services
```

### 7. Enable Security Features

```bash
# Enable Security Command Center (if available)
gcloud services enable securitycenter.googleapis.com

# Enable Cloud Asset Inventory
gcloud services enable cloudasset.googleapis.com

# Set up VPC Service Controls
gcloud services enable accesscontextmanager.googleapis.com
```

### 8. Regular Access Reviews

**Audit IAM regularly**:

```bash
# Export IAM policy
gcloud projects get-iam-policy my-first-gcp-project \
  --format=json > iam-policy-$(date +%Y%m%d).json

# Find users with Owner role
gcloud projects get-iam-policy my-first-gcp-project \
  --flatten="bindings[].members" \
  --filter="bindings.role:roles/owner" \
  --format="table(bindings.members)"

# Find service accounts with keys
gcloud iam service-accounts list --format="value(email)" | while read SA; do
  echo "Service Account: $SA"
  gcloud iam service-accounts keys list --iam-account=$SA
done
```

### 9. Use Conditions and Temporary Access

```bash
# Grant temporary access (expires in 30 days)
gcloud projects add-iam-policy-binding my-first-gcp-project \
  --member="user:contractor@example.com" \
  --role="roles/viewer" \
  --condition='expression=request.time < timestamp("'$(date -d '+30 days' -I)'T23:59:59Z"),title=30_day_access,description=Access expires in 30 days'
```

### 10. Monitor and Alert

**Set up monitoring**:

```bash
# Create log metric for IAM changes
gcloud logging metrics create iam-policy-changes \
  --description="Tracks IAM policy changes" \
  --log-filter='protoPayload.methodName="SetIamPolicy" OR protoPayload.methodName="SetIamPolicyRequest"'

# Create alert policy
gcloud alpha monitoring policies create \
  --notification-channels=CHANNEL_ID \
  --display-name="IAM Policy Changes Alert" \
  --condition-display-name="IAM changes detected" \
  --condition-threshold-value=1 \
  --condition-threshold-duration=0s
```

---

## Summary Checklist

**Project Setup**:
- [ ] GCP free tier account created
- [ ] New project created
- [ ] Billing account linked
- [ ] Budget alerts configured

**IAM Configuration**:
- [ ] Custom IAM roles created
- [ ] Service accounts created
- [ ] Service account keys generated and secured
- [ ] Users invited and roles assigned
- [ ] Permissions tested and verified

**Security**:
- [ ] Least privilege principle applied
- [ ] Primitive roles avoided
- [ ] Audit logging enabled
- [ ] Regular access reviews scheduled
- [ ] Organization policies configured (if applicable)

**Testing**:
- [ ] Service account access verified
- [ ] User permissions tested
- [ ] Policy simulator used
- [ ] Audit logs reviewed

---

## Additional Resources

**Official Documentation**:
- [GCP IAM Overview](https://cloud.google.com/iam/docs/overview)
- [IAM Roles Reference](https://cloud.google.com/iam/docs/understanding-roles)
- [Best Practices for IAM](https://cloud.google.com/iam/docs/best-practices)
- [Service Account Best Practices](https://cloud.google.com/iam/docs/best-practices-service-accounts)

**Training**:
- [Google Cloud Skills Boost](https://www.cloudskillsboost.google/)
- [IAM Qwiklabs](https://www.cloudskillsboost.google/quests/44)

**Tools**:
- [IAM Policy Simulator](https://console.cloud.google.com/iam-admin/troubleshooter)
- [IAM Recommender](https://console.cloud.google.com/iam-admin/recommender)
- [Cloud Asset Inventory](https://console.cloud.google.com/security/command-center/assets)

---

## Conclusion

This hands-on guide covered the complete process of setting up a GCP project with proper IAM configuration. You've learned how to create projects, manage users and service accounts, implement custom roles, and follow security best practices. Regular auditing and adherence to the principle of least privilege will help maintain a secure GCP environment.

Remember: Security is an ongoing process, not a one-time setup!
