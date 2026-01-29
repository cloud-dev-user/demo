# GCP IAM Troubleshooting Cheat Sheet

Quick reference guide for diagnosing and fixing common GCP IAM issues.

---

## Quick Diagnostic Commands

### Check Current Authentication
```bash
# Who am I?
gcloud auth list

# Active account
gcloud config get-value account

# Active project
gcloud config get-value project
```

### Check Permissions
```bash
# Get current user's permissions
gcloud projects get-iam-policy PROJECT_ID \
  --flatten="bindings[].members" \
  --filter="bindings.members:user:$(gcloud config get-value account)" \
  --format="table(bindings.role)"

# Check service account permissions
gcloud projects get-iam-policy PROJECT_ID \
  --flatten="bindings[].members" \
  --filter="bindings.members:serviceAccount:SA_EMAIL" \
  --format="table(bindings.role)"

# Test specific permission
gcloud projects get-iam-policy PROJECT_ID \
  --flatten="bindings[].members" \
  --filter="bindings.members:user:USER_EMAIL AND bindings.role:ROLE_NAME"
```

---

## Common Errors & Solutions

### Error: "Permission Denied" / 403 Forbidden

**Symptom**: Cannot perform action, get 403 error

**Quick Checks**:
```bash
# 1. Verify you're using the right project
gcloud config list

# 2. Check if API is enabled
gcloud services list --enabled | grep SERVICE_NAME

# 3. Check your permissions
gcloud projects get-iam-policy PROJECT_ID --flatten="bindings[].members" \
  --filter="bindings.members:user:$(gcloud config get-value account)"
```

**Common Fixes**:
```bash
# Enable the API
gcloud services enable SERVICE_NAME.googleapis.com

# Wait for IAM propagation (up to 80 seconds)
sleep 80

# Refresh credentials
gcloud auth application-default login

# Check organization policies
gcloud resource-manager org-policies list --project=PROJECT_ID
```

---

### Error: Service Account Authentication Failed

**Symptom**: Service account key doesn't work

**Diagnosis**:
```bash
# List all keys for service account
gcloud iam service-accounts keys list \
  --iam-account=SA_EMAIL

# Verify JSON key structure
cat key.json | jq -r '.type, .project_id, .private_key_id'
```

**Solutions**:
```bash
# 1. Ensure GOOGLE_APPLICATION_CREDENTIALS is set
export GOOGLE_APPLICATION_CREDENTIALS="/path/to/key.json"

# 2. Verify file permissions (should be 600)
chmod 600 /path/to/key.json

# 3. Test authentication
gcloud auth activate-service-account --key-file=/path/to/key.json

# 4. Generate new key if corrupted
gcloud iam service-accounts keys create new-key.json \
  --iam-account=SA_EMAIL

# 5. Check if service account is enabled
gcloud iam service-accounts describe SA_EMAIL
```

---

### Error: Billing Not Enabled

**Symptom**: "Billing account not configured" when creating resources

**Quick Fix**:
```bash
# Check billing status
gcloud billing projects describe PROJECT_ID

# List billing accounts
gcloud billing accounts list

# Link billing account
gcloud billing projects link PROJECT_ID \
  --billing-account=BILLING_ACCOUNT_ID

# Verify
gcloud billing projects describe PROJECT_ID
```

---

### Error: API Not Enabled

**Symptom**: "SERVICE_NAME API has not been used in project..."

**Quick Fix**:
```bash
# Enable specific API
gcloud services enable SERVICE_NAME.googleapis.com

# Enable multiple APIs
gcloud services enable \
  compute.googleapis.com \
  storage.googleapis.com \
  iam.googleapis.com

# Verify enabled APIs
gcloud services list --enabled
```

---

### Error: Quota Exceeded

**Symptom**: "Quota exceeded for quota metric..."

**Diagnosis**:
```bash
# Check project quotas
gcloud compute project-info describe --project=PROJECT_ID

# Check specific service quotas
gcloud compute regions describe REGION --project=PROJECT_ID
```

**Solutions**:
1. Request quota increase in Console: IAM & Admin → Quotas
2. Use different region
3. Delete unused resources
4. Use smaller instance types

---

### Error: Organization Policy Constraint Violation

**Symptom**: "Organization policy constraint..."

**Diagnosis**:
```bash
# List all organization policies
gcloud resource-manager org-policies list --project=PROJECT_ID

# Describe specific policy
gcloud resource-manager org-policies describe CONSTRAINT_NAME \
  --project=PROJECT_ID

# Example: Check resource location restrictions
gcloud resource-manager org-policies describe \
  constraints/gcp.resourceLocations --project=PROJECT_ID
```

**Solutions**:
```bash
# View inherited policies
gcloud resource-manager org-policies list --project=PROJECT_ID \
  --show-inherited

# Request policy exception (requires org admin)
# Or adjust resources to comply with policy
```

---

### Error: Custom Role Creation Failed

**Symptom**: Cannot create or update custom role

**Common Issues**:

1. **Invalid Permission Name**:
```bash
# List valid permissions for a service
gcloud iam list-testable-permissions //SERVICE.googleapis.com

# Example for Storage
gcloud iam list-testable-permissions //storage.googleapis.com
```

2. **Missing IAM Admin Permission**:
```bash
# Check if you have role creation permission
gcloud projects get-iam-policy PROJECT_ID \
  --flatten="bindings[].members" \
  --filter="bindings.members:user:$(gcloud config get-value account)" | \
  grep "roles/iam.roleAdmin"
```

3. **Role ID Conflict**:
```bash
# List existing custom roles
gcloud iam roles list --project=PROJECT_ID

# Use different role ID
gcloud iam roles create UNIQUE_ROLE_ID --project=PROJECT_ID --file=role.yaml
```

---

### Error: IAM Changes Not Taking Effect

**Symptom**: Permissions granted but still getting denied

**Reasons & Solutions**:

1. **IAM Propagation Delay** (most common):
```bash
# Wait up to 80 seconds
sleep 80
# Retry operation
```

2. **Cached Credentials**:
```bash
# Revoke and re-authenticate
gcloud auth application-default revoke
gcloud auth application-default login
```

3. **Wrong Service Account**:
```bash
# Verify which SA is being used
gcloud auth list
# Switch if needed
gcloud config set account SERVICE_ACCOUNT_EMAIL
```

4. **Organization Policy Override**:
```bash
# Check for conflicting org policies
gcloud resource-manager org-policies list --project=PROJECT_ID
```

---

### Error: Service Account Key Limit Reached

**Symptom**: "Limit exceeded for resource 'keys'"

**Solution**:
```bash
# List all keys
gcloud iam service-accounts keys list --iam-account=SA_EMAIL

# Delete old keys (user-managed only)
gcloud iam service-accounts keys delete KEY_ID \
  --iam-account=SA_EMAIL

# Automated cleanup of keys older than 90 days
for key in $(gcloud iam service-accounts keys list \
  --iam-account=SA_EMAIL \
  --filter="validAfterTime<'-90d'" \
  --format="value(name)"); do
  gcloud iam service-accounts keys delete $key \
    --iam-account=SA_EMAIL --quiet
done
```

**Limit**: 10 keys per service account

---

## IAM Debugging Workflow

### Step 1: Identify the Problem
```bash
# What action is failing?
# Example: gsutil ls gs://bucket-name

# What error message?
# Example: "AccessDenied: 403 user@example.com does not have permission"
```

### Step 2: Check Basic Configuration
```bash
# Verify project
gcloud config list

# Verify authentication
gcloud auth list

# Verify project number/ID match
gcloud projects describe PROJECT_ID
```

### Step 3: Check API Enablement
```bash
# Is the API enabled?
gcloud services list --enabled | grep SERVICE_NAME

# Enable if needed
gcloud services enable SERVICE_NAME.googleapis.com
```

### Step 4: Check IAM Permissions
```bash
# What roles does the user/SA have?
gcloud projects get-iam-policy PROJECT_ID \
  --flatten="bindings[].members" \
  --filter="bindings.members:MEMBER_TYPE:EMAIL"

# What permissions does the role include?
gcloud iam roles describe ROLE_NAME
```

### Step 5: Use Policy Troubleshooter
```bash
# Console: IAM & Admin → Policy Troubleshooter
# Or use gcloud
gcloud policy-intelligence troubleshoot-iam \
  --resource=//RESOURCE_PATH \
  --permission=PERMISSION_NAME \
  --principal=PRINCIPAL
```

### Step 6: Check Organization Policies
```bash
# Any restrictive policies?
gcloud resource-manager org-policies list --project=PROJECT_ID

# Check specific constraint
gcloud resource-manager org-policies describe CONSTRAINT \
  --project=PROJECT_ID
```

---

## Quick Reference: Common Roles

### Primitive Roles (Avoid in Production)
- `roles/viewer` - Read-only access
- `roles/editor` - Edit access (no IAM changes)
- `roles/owner` - Full access including IAM

### Common Predefined Roles

**Compute Engine**:
- `roles/compute.instanceAdmin.v1` - Manage instances
- `roles/compute.networkAdmin` - Manage networks
- `roles/compute.securityAdmin` - Manage firewalls

**Storage**:
- `roles/storage.objectViewer` - Read objects
- `roles/storage.objectCreator` - Upload objects
- `roles/storage.objectAdmin` - Manage objects
- `roles/storage.admin` - Manage buckets and objects

**IAM**:
- `roles/iam.serviceAccountAdmin` - Manage service accounts
- `roles/iam.serviceAccountUser` - Use service accounts
- `roles/iam.roleAdmin` - Manage custom roles

**BigQuery**:
- `roles/bigquery.dataViewer` - Read data
- `roles/bigquery.dataEditor` - Edit data
- `roles/bigquery.admin` - Full BigQuery access

---

## Emergency IAM Recovery

### Lost Access to Project

**If you're the owner**:
```bash
# List all projects you have access to
gcloud projects list

# Try to access through organization
gcloud organizations list

# Contact Google Cloud Support
```

**If service account key is compromised**:
```bash
# Immediately disable all keys
for key in $(gcloud iam service-accounts keys list \
  --iam-account=SA_EMAIL \
  --format="value(name)" \
  --filter="keyType=USER_MANAGED"); do
  gcloud iam service-accounts keys delete $key \
    --iam-account=SA_EMAIL --quiet
done

# Remove service account from project
gcloud projects remove-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:SA_EMAIL" \
  --role=ROLE_NAME

# Create new service account
gcloud iam service-accounts create new-sa-name
```

### Accidentally Removed Critical Permissions

**View audit logs**:
```bash
# Find recent IAM changes
gcloud logging read "protoPayload.methodName='SetIamPolicy'" \
  --limit=10 \
  --format=json > iam-changes.json

# Review and restore previous policy
gcloud projects set-iam-policy PROJECT_ID previous-policy.json
```

**Restore from backup** (if you have one):
```bash
# Always backup before changes
gcloud projects get-iam-policy PROJECT_ID > backup-$(date +%Y%m%d).json

# Restore
gcloud projects set-iam-policy PROJECT_ID backup-YYYYMMDD.json
```

---

## Best Practice Checklist

### Before Making Changes
- [ ] Backup current IAM policy: `gcloud projects get-iam-policy PROJECT_ID > backup.json`
- [ ] Review impact of changes
- [ ] Test in dev/staging first
- [ ] Document changes

### After Making Changes
- [ ] Wait 80 seconds for propagation
- [ ] Test access with affected accounts
- [ ] Verify in audit logs
- [ ] Update documentation

### Regular Maintenance
- [ ] Review IAM policy monthly
- [ ] Rotate service account keys quarterly
- [ ] Remove unused accounts
- [ ] Audit overprivileged roles
- [ ] Update organization policies

---

## Useful One-Liners

### Find all users with Owner role
```bash
gcloud projects get-iam-policy PROJECT_ID \
  --flatten="bindings[].members" \
  --filter="bindings.role:roles/owner" \
  --format="value(bindings.members)"
```

### List all service accounts with keys
```bash
for sa in $(gcloud iam service-accounts list --format="value(email)"); do
  echo "=== $sa ==="; 
  gcloud iam service-accounts keys list --iam-account=$sa;
done
```

### Find permissions for a specific action
```bash
# Example: Find what permissions allow bucket deletion
gcloud iam list-testable-permissions //storage.googleapis.com | \
  grep -i delete
```

### Export complete IAM configuration
```bash
{
  echo "Project: $PROJECT_ID"
  echo "=== IAM Policy ==="
  gcloud projects get-iam-policy $PROJECT_ID
  echo "=== Service Accounts ==="
  gcloud iam service-accounts list
  echo "=== Custom Roles ==="
  gcloud iam roles list --project=$PROJECT_ID
} > iam-complete-$(date +%Y%m%d).txt
```

### Check for overprivileged service accounts
```bash
gcloud projects get-iam-policy PROJECT_ID \
  --flatten="bindings[].members" \
  --filter="bindings.members:serviceAccount:* AND (bindings.role:roles/owner OR bindings.role:roles/editor)"
```

### Monitor IAM changes in real-time
```bash
gcloud logging tail "protoPayload.methodName='SetIamPolicy'" \
  --format="table(timestamp, protoPayload.authenticationInfo.principalEmail, protoPayload.resourceName)"
```

---

## Support Resources

### Documentation
- IAM Overview: https://cloud.google.com/iam/docs
- Troubleshooting: https://cloud.google.com/iam/docs/troubleshooting
- Best Practices: https://cloud.google.com/iam/docs/best-practices

### Tools
- Policy Troubleshooter: https://console.cloud.google.com/iam-admin/troubleshooter
- IAM Recommender: https://console.cloud.google.com/iam-admin/recommender
- Policy Simulator: https://console.cloud.google.com/iam-admin/policy-simulator

### Getting Help
- Stack Overflow: Tag `google-cloud-platform` and `google-cloud-iam`
- Google Cloud Community: https://www.googlecloudcommunity.com
- Support: https://cloud.google.com/support

---

## Quick Decision Tree

```
Permission Denied Error
├─ Is API enabled?
│  ├─ No → Enable API
│  └─ Yes → Continue
├─ Do you have the right role?
│  ├─ No → Request access
│  └─ Yes → Continue
├─ Recent IAM change?
│  ├─ Yes → Wait 80 seconds
│  └─ No → Continue
├─ Organization policy blocking?
│  ├─ Yes → Request exception
│  └─ No → Continue
└─ Contact support
```

---

**Remember**: When in doubt, check the audit logs! They contain a complete history of all IAM changes.
