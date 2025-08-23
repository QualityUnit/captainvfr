#!/bin/bash

# Amplify CI/CD Lambda Deployment Script
# This script runs during Amplify build process to deploy/update Lambda function

set -e  # Exit on error

echo "======================================"
echo "SafeSky Lambda Auto-Deployment"
echo "======================================"

# Configuration
FUNCTION_NAME="captainvfr-safesky-proxy"
HANDLER="index.handler"
RUNTIME="nodejs20.x"
TIMEOUT=30
MEMORY=512
ROLE_NAME="captainvfr-lambda-role"

# Get AWS account ID - in Amplify build environment, credentials are already configured
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "444348080366")
AWS_REGION=${AWS_REGION:-"eu-central-1"}

# In Amplify build environment, we don't need to specify profile
unset AWS_PROFILE

echo "AWS Account: $AWS_ACCOUNT_ID"
echo "AWS Region: $AWS_REGION"

# Navigate to Lambda directory
cd backend/lambda/safesky-proxy

# Create deployment package
echo "Creating deployment package..."
zip -q deployment-package.zip index.js package.json

# Check if IAM role exists, create if not
echo "Checking IAM role..."
if ! aws iam get-role --role-name $ROLE_NAME 2>/dev/null; then
    echo "Creating IAM role..."
    aws iam create-role \
        --role-name $ROLE_NAME \
        --assume-role-policy-document '{
            "Version": "2012-10-17",
            "Statement": [{
                "Effect": "Allow",
                "Principal": {"Service": "lambda.amazonaws.com"},
                "Action": "sts:AssumeRole"
            }]
        }'
    
    # Attach basic Lambda execution policy
    aws iam attach-role-policy \
        --role-name $ROLE_NAME \
        --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
    
    # Wait for role to be available
    sleep 10
fi

ROLE_ARN="arn:aws:iam::$AWS_ACCOUNT_ID:role/$ROLE_NAME"

# Check if Lambda function exists
echo "Checking if Lambda function exists..."
if aws lambda get-function --function-name $FUNCTION_NAME 2>/dev/null; then
    echo "Updating existing Lambda function..."
    aws lambda update-function-code \
        --function-name $FUNCTION_NAME \
        --zip-file fileb://deployment-package.zip \
        --publish
    
    # Update configuration if environment variables changed
    aws lambda update-function-configuration \
        --function-name $FUNCTION_NAME \
        --timeout $TIMEOUT \
        --memory-size $MEMORY \
        --environment "Variables={
            SAFESKY_API_KEY=${SAFESKY_API_KEY:-},
            CACHE_TTL=20,
            ALLOWED_ORIGIN=*
        }"
else
    echo "Creating new Lambda function..."
    aws lambda create-function \
        --function-name $FUNCTION_NAME \
        --runtime $RUNTIME \
        --role $ROLE_ARN \
        --handler $HANDLER \
        --zip-file fileb://deployment-package.zip \
        --timeout $TIMEOUT \
        --memory-size $MEMORY \
        --environment "Variables={
            SAFESKY_API_KEY=${SAFESKY_API_KEY:-},
            CACHE_TTL=20,
            ALLOWED_ORIGIN=*
        }" \
        --publish
fi

# Clean up
rm deployment-package.zip

# Get function ARN for output
FUNCTION_ARN=$(aws lambda get-function --function-name $FUNCTION_NAME --query 'Configuration.FunctionArn' --output text)

echo ""
echo "======================================"
echo "Lambda Deployment Complete!"
echo "======================================"
echo "Function Name: $FUNCTION_NAME"
echo "Function ARN: $FUNCTION_ARN"
echo ""

# Check if API Gateway exists
API_NAME="CaptainVFR-SafeSky-API"
API_ID=$(aws apigateway get-rest-apis --query "items[?name=='$API_NAME'].id" --output text)

if [ -z "$API_ID" ]; then
    echo "Note: API Gateway not found. Create it manually or run setup script."
else
    echo "API Gateway ID: $API_ID"
    echo "API Endpoint: https://$API_ID.execute-api.$AWS_REGION.amazonaws.com/prod/beacons"
fi