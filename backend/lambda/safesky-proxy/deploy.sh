#!/bin/bash

# Deployment script for SafeSky Lambda function
# This script uses AWS SAM CLI to deploy the function

echo "======================================"
echo "SafeSky Lambda Deployment Script"
echo "======================================"

# Check if SAM CLI is installed
if ! command -v sam &> /dev/null; then
    echo "Error: AWS SAM CLI is not installed."
    echo "Install it with: brew install aws-sam-cli"
    exit 1
fi

# Check if AWS CLI is configured
if ! aws sts get-caller-identity &> /dev/null; then
    echo "Error: AWS CLI is not configured."
    echo "Run: aws configure"
    exit 1
fi

# Get AWS account ID and region
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=$(aws configure get region)
STACK_NAME="captainvfr-safesky-api"

echo "Deploying to AWS Account: $AWS_ACCOUNT_ID"
echo "Region: $AWS_REGION"
echo "Stack Name: $STACK_NAME"
echo ""

# Ask for SafeSky API key
read -p "Enter your SafeSky API key (or press Enter to skip): " SAFESKY_API_KEY

# Build the Lambda function
echo "Building Lambda function..."
sam build

# Deploy the function
echo "Deploying to AWS..."
if [ -z "$SAFESKY_API_KEY" ]; then
    echo "Deploying without API key (will use mock data)..."
    sam deploy \
        --stack-name $STACK_NAME \
        --capabilities CAPABILITY_IAM \
        --resolve-s3 \
        --parameter-overrides SafeSkyApiKey=""
else
    echo "Deploying with SafeSky API key..."
    sam deploy \
        --stack-name $STACK_NAME \
        --capabilities CAPABILITY_IAM \
        --resolve-s3 \
        --parameter-overrides SafeSkyApiKey="$SAFESKY_API_KEY"
fi

# Get the API endpoint
echo ""
echo "======================================"
echo "Deployment Complete!"
echo "======================================"
echo ""
echo "API Endpoint:"
aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --query "Stacks[0].Outputs[?OutputKey=='ApiEndpoint'].OutputValue" \
    --output text

echo ""
echo "Update your Flutter app with this endpoint in:"
echo "lib/services/safesky_service.dart"