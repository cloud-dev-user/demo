#!/bin/bash

################################################################################
# GCP IAM Setup Automation Script
# This script automates common GCP project and IAM setup tasks
################################################################################

set -e  # Exit on error
set -u  # Exit on undefined variable

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Configuration
PROJECT_ID="${1:-my-first-gcp-project}"
PROJECT_NAME="My First GCP Project"
REGION="us-central1"
ZONE="us-central1-a"

################################################################################
# Function: Check Prerequisites
################################################################################
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if gcloud is installed
    if ! command -v gcloud &> /dev/null; then
        log_error "gcloud CLI is not installed. Please install from: https://cloud.google.com/sdk/docs/install"
        exit 1
    fi
    
    # Check authentication
    if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" &> /dev/null; then
        log_warning "Not authenticated. Running gcloud auth login..."
        gcloud auth login
    fi
    
    log_success "Prerequisites check passed"
}

################################################################################
# Function: Create Project
################################################################################
create_project() {
    log_info "Creating project: $PROJECT_ID..."
    
    # Check if project already exists
    if gcloud projects describe "$PROJECT_ID" &> /dev/null; then
        log_warning "Project $PROJECT_ID already exists"
        read -p "Do you want to use the existing project? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_error "Exiting..."
            exit 1
        fi
    else
        # Create new project
        gcloud projects create "$PROJECT_ID" --name="$PROJECT_NAME"
        log_success "Project created: $PROJECT_ID"
    fi
    
    # Set active project
    gcloud config set project "$PROJECT_ID"
    log_success "Active project set to: $PROJECT_ID"
}

################################################################################
# Function: Setup Billing
################################################################################
setup_billing() {
    log_info "Setting up billing..."
    
    # List billing accounts
    BILLING_ACCOUNTS=$(gcloud billing accounts list --format="value(name)" 2>/dev/null)
    
    if [ -z "$BILLING_ACCOUNTS" ]; then
        log_warning "No billing accounts found. Please set up billing manually in the console."
        return 1
    fi
    
    # Use first billing account
    BILLING_ACCOUNT=$(echo "$BILLING_ACCOUNTS" | head -n 1)
    log_info "Using billing account: $BILLING_ACCOUNT"
    
    # Link billing account
    gcloud billing projects link "$PROJECT_ID" --billing-account="$BILLING_ACCOUNT"
    log_success "Billing account linked to project"
}

################################################################################
# Function: Enable Required APIs
################################################################################
enable_apis() {
    log_info "Enabling required APIs..."
    
    APIS=(
        "iam.googleapis.com"
        "cloudresourcemanager.googleapis.com"
        "serviceusage.googleapis.com"
        "storage.googleapis.com"
        "compute.googleapis.com"
        "logging.googleapis.com"
        "monitoring.googleapis.com"
    )
    
    for api in "${APIS[@]}"; do
        log_info "Enabling $api..."
        gcloud services enable "$api" --project="$PROJECT_ID"
    done
    
    log_success "All required APIs enabled"
}

################################################################################
# Function: Create Custom IAM Role
################################################################################
create_custom_role() {
    log_info "Creating custom IAM role..."
    
    ROLE_ID="customStorageAdmin"
    ROLE_FILE="/tmp/custom-role-${ROLE_ID}.yaml"
    
    cat > "$ROLE_FILE" <<EOF
title: "Custom Storage Admin"
description: "Custom role for storage administration with limited permissions"
stage: "GA"
includedPermissions:
- storage.buckets.create
- storage.buckets.get
- storage.buckets.list
- storage.buckets.update
- storage.objects.create
- storage.objects.delete
- storage.objects.get
- storage.objects.list
EOF
    
    # Check if role exists
    if gcloud iam roles describe "$ROLE_ID" --project="$PROJECT_ID" &> /dev/null; then
        log_warning "Role $ROLE_ID already exists. Updating..."
        gcloud iam roles update "$ROLE_ID" --project="$PROJECT_ID" --file="$ROLE_FILE"
    else
        gcloud iam roles create "$ROLE_ID" --project="$PROJECT_ID" --file="$ROLE_FILE"
    fi
    
    log_success "Custom role created/updated: $ROLE_ID"
    rm -f "$ROLE_FILE"
}

################################################################################
# Function: Create Service Account
################################################################################
create_service_account() {
    log_info "Creating service account..."
    
    SA_NAME="webapp-storage-sa"
    SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
    SA_DISPLAY_NAME="Web Application Storage Service Account"
    
    # Check if service account exists
    if gcloud iam service-accounts describe "$SA_EMAIL" &> /dev/null; then
        log_warning "Service account $SA_NAME already exists"
    else
        gcloud iam service-accounts create "$SA_NAME" \
            --description="Service account for web application storage access" \
            --display-name="$SA_DISPLAY_NAME"
        log_success "Service account created: $SA_EMAIL"
    fi
    
    # Assign role to service account
    log_info "Assigning Storage Object Viewer role to service account..."
    gcloud projects add-iam-policy-binding "$PROJECT_ID" \
        --member="serviceAccount:$SA_EMAIL" \
        --role="roles/storage.objectViewer" \
        --condition=None
    
    log_success "Role assigned to service account"
    
    # Generate key
    KEY_FILE="$HOME/${SA_NAME}-key.json"
    
    read -p "Do you want to generate a service account key? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if [ -f "$KEY_FILE" ]; then
            log_warning "Key file already exists: $KEY_FILE"
            read -p "Overwrite? (y/n): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                log_info "Skipping key generation"
                return 0
            fi
        fi
        
        gcloud iam service-accounts keys create "$KEY_FILE" \
            --iam-account="$SA_EMAIL"
        
        chmod 600 "$KEY_FILE"
        log_success "Service account key created: $KEY_FILE"
        log_warning "IMPORTANT: Keep this key secure and never commit it to version control!"
    fi
}

################################################################################
# Function: Create Additional Service Accounts
################################################################################
create_additional_service_accounts() {
    log_info "Creating additional service accounts for different use cases..."
    
    # Compute Admin SA
    SA_COMPUTE="compute-admin-sa"
    SA_COMPUTE_EMAIL="${SA_COMPUTE}@${PROJECT_ID}.iam.gserviceaccount.com"
    
    if ! gcloud iam service-accounts describe "$SA_COMPUTE_EMAIL" &> /dev/null; then
        gcloud iam service-accounts create "$SA_COMPUTE" \
            --description="Service account for compute instance management" \
            --display-name="Compute Admin Service Account"
        
        gcloud projects add-iam-policy-binding "$PROJECT_ID" \
            --member="serviceAccount:$SA_COMPUTE_EMAIL" \
            --role="roles/compute.instanceAdmin.v1"
        
        log_success "Compute Admin service account created"
    fi
    
    # BigQuery Reader SA
    SA_BQ="bigquery-reader-sa"
    SA_BQ_EMAIL="${SA_BQ}@${PROJECT_ID}.iam.gserviceaccount.com"
    
    if ! gcloud iam service-accounts describe "$SA_BQ_EMAIL" &> /dev/null; then
        gcloud iam service-accounts create "$SA_BQ" \
            --description="Service account for BigQuery data reading" \
            --display-name="BigQuery Reader Service Account"
        
        gcloud projects add-iam-policy-binding "$PROJECT_ID" \
            --member="serviceAccount:$SA_BQ_EMAIL" \
            --role="roles/bigquery.dataViewer"
        
        log_success "BigQuery Reader service account created"
    fi
}

################################################################################
# Function: Add IAM Users
################################################################################
add_iam_users() {
    log_info "Adding IAM users..."
    
    read -p "Enter developer email address (or press Enter to skip): " DEV_EMAIL
    
    if [ -n "$DEV_EMAIL" ]; then
        log_info "Adding developer: $DEV_EMAIL with Editor role..."
        gcloud projects add-iam-policy-binding "$PROJECT_ID" \
            --member="user:$DEV_EMAIL" \
            --role="roles/editor"
        log_success "Developer added: $DEV_EMAIL"
    fi
    
    read -p "Enter viewer email address (or press Enter to skip): " VIEWER_EMAIL
    
    if [ -n "$VIEWER_EMAIL" ]; then
        log_info "Adding viewer: $VIEWER_EMAIL with Viewer role..."
        gcloud projects add-iam-policy-binding "$PROJECT_ID" \
            --member="user:$VIEWER_EMAIL" \
            --role="roles/viewer"
        log_success "Viewer added: $VIEWER_EMAIL"
    fi
}

################################################################################
# Function: Setup Audit Logging
################################################################################
setup_audit_logging() {
    log_info "Setting up audit logging..."
    
    # Create log sink for IAM changes
    SINK_NAME="iam-changes-sink"
    DESTINATION="logging.googleapis.com/projects/${PROJECT_ID}/locations/global/buckets/_Default"
    FILTER='protoPayload.methodName="SetIamPolicy" OR protoPayload.methodName="google.iam.admin.v1.CreateServiceAccount"'
    
    if gcloud logging sinks describe "$SINK_NAME" &> /dev/null; then
        log_warning "Log sink $SINK_NAME already exists"
    else
        gcloud logging sinks create "$SINK_NAME" \
            "$DESTINATION" \
            --log-filter="$FILTER"
        log_success "Audit log sink created"
    fi
}

################################################################################
# Function: Create Test Resources
################################################################################
create_test_resources() {
    log_info "Creating test resources..."
    
    # Create test storage bucket
    BUCKET_NAME="${PROJECT_ID}-test-bucket"
    
    if gsutil ls -b "gs://${BUCKET_NAME}" &> /dev/null; then
        log_warning "Bucket $BUCKET_NAME already exists"
    else
        gsutil mb -p "$PROJECT_ID" -l "$REGION" "gs://${BUCKET_NAME}/"
        log_success "Test bucket created: gs://${BUCKET_NAME}"
        
        # Upload test file
        echo "Test content - $(date)" > /tmp/test-file.txt
        gsutil cp /tmp/test-file.txt "gs://${BUCKET_NAME}/"
        rm /tmp/test-file.txt
        log_success "Test file uploaded to bucket"
    fi
}

################################################################################
# Function: Verify Setup
################################################################################
verify_setup() {
    log_info "Verifying setup..."
    
    echo ""
    echo "========================================="
    echo "PROJECT INFORMATION"
    echo "========================================="
    gcloud projects describe "$PROJECT_ID" --format="table(projectId,name,projectNumber,lifecycleState)"
    
    echo ""
    echo "========================================="
    echo "ENABLED APIS"
    echo "========================================="
    gcloud services list --enabled --format="table(config.name,config.title)" | head -n 10
    
    echo ""
    echo "========================================="
    echo "SERVICE ACCOUNTS"
    echo "========================================="
    gcloud iam service-accounts list --format="table(email,displayName)"
    
    echo ""
    echo "========================================="
    echo "CUSTOM ROLES"
    echo "========================================="
    gcloud iam roles list --project="$PROJECT_ID" --format="table(name,title,stage)"
    
    echo ""
    echo "========================================="
    echo "IAM POLICY BINDINGS"
    echo "========================================="
    gcloud projects get-iam-policy "$PROJECT_ID" --format="table(bindings.role,bindings.members)" | head -n 20
    
    echo ""
    log_success "Setup verification complete!"
}

################################################################################
# Function: Generate Summary Report
################################################################################
generate_report() {
    log_info "Generating setup summary report..."
    
    REPORT_FILE="gcp-setup-report-${PROJECT_ID}-$(date +%Y%m%d-%H%M%S).txt"
    
    {
        echo "========================================="
        echo "GCP PROJECT SETUP REPORT"
        echo "========================================="
        echo "Generated: $(date)"
        echo "Project ID: $PROJECT_ID"
        echo ""
        
        echo "PROJECT DETAILS:"
        gcloud projects describe "$PROJECT_ID"
        echo ""
        
        echo "SERVICE ACCOUNTS:"
        gcloud iam service-accounts list
        echo ""
        
        echo "CUSTOM ROLES:"
        gcloud iam roles list --project="$PROJECT_ID"
        echo ""
        
        echo "IAM POLICY:"
        gcloud projects get-iam-policy "$PROJECT_ID"
        echo ""
        
        echo "ENABLED SERVICES:"
        gcloud services list --enabled
        echo ""
        
    } > "$REPORT_FILE"
    
    log_success "Report generated: $REPORT_FILE"
}

################################################################################
# Function: Cleanup (Optional)
################################################################################
cleanup() {
    log_warning "This will delete all resources created by this script!"
    read -p "Are you sure you want to cleanup? (yes/NO): " -r
    
    if [[ $REPLY != "yes" ]]; then
        log_info "Cleanup cancelled"
        return 0
    fi
    
    log_info "Cleaning up resources..."
    
    # Delete service account keys
    for SA in $(gcloud iam service-accounts list --format="value(email)"); do
        log_info "Deleting keys for $SA..."
        for KEY in $(gcloud iam service-accounts keys list --iam-account="$SA" --format="value(name)" --filter="keyType=USER_MANAGED"); do
            gcloud iam service-accounts keys delete "$KEY" --iam-account="$SA" --quiet
        done
    done
    
    # Delete test bucket
    BUCKET_NAME="${PROJECT_ID}-test-bucket"
    if gsutil ls -b "gs://${BUCKET_NAME}" &> /dev/null; then
        gsutil -m rm -r "gs://${BUCKET_NAME}"
        log_success "Test bucket deleted"
    fi
    
    log_warning "To delete the project completely, run:"
    log_warning "gcloud projects delete $PROJECT_ID"
}

################################################################################
# Main Function
################################################################################
main() {
    echo ""
    echo "========================================="
    echo "GCP IAM SETUP AUTOMATION SCRIPT"
    echo "========================================="
    echo ""
    
    check_prerequisites
    
    echo ""
    echo "This script will set up a GCP project with IAM configuration"
    echo "Project ID: $PROJECT_ID"
    echo ""
    read -p "Do you want to continue? (y/n): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Exiting..."
        exit 0
    fi
    
    create_project
    setup_billing
    enable_apis
    create_custom_role
    create_service_account
    create_additional_service_accounts
    add_iam_users
    setup_audit_logging
    create_test_resources
    verify_setup
    generate_report
    
    echo ""
    log_success "========================================="
    log_success "GCP PROJECT SETUP COMPLETE!"
    log_success "========================================="
    echo ""
    echo "Next steps:"
    echo "1. Review the generated report"
    echo "2. Test service account access"
    echo "3. Configure organization policies if applicable"
    echo "4. Set up budget alerts in the console"
    echo "5. Review and adjust IAM permissions as needed"
    echo ""
    
    read -p "Would you like to run cleanup? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        cleanup
    fi
}

# Run main function
main
