#!/bin/bash

# Simple deployment script using AWS CLI (no SAM required)

echo "======================================"
echo "SafeSky Lambda Simple Deployment"
echo "======================================"

# Configuration
FUNCTION_NAME="captainvfr-safesky-proxy"
HANDLER="index.handler"
RUNTIME="nodejs20.x"
TIMEOUT=30
MEMORY=512
REGION=${AWS_REGION:-"us-east-1"}

# Check AWS CLI
if ! command -v aws &> /dev/null; then
    echo "Error: AWS CLI is not installed."
    exit 1
fi

# Get SafeSky API key
echo "Enter your SafeSky API key (or press Enter for mock data):"
read -s SAFESKY_API_KEY

# Create deployment package
echo "Creating deployment package..."
zip -q deployment-package.zip index.js package.json

# Check if function exists
echo "Checking if Lambda function exists..."
if aws lambda get-function --function-name $FUNCTION_NAME 2>/dev/null; then
    echo "Updating existing function..."
    aws lambda update-function-code \
        --function-name $FUNCTION_NAME \
        --zip-file fileb://deployment-package.zip
    
    # Update environment variables
    aws lambda update-function-configuration \
        --function-name $FUNCTION_NAME \
        --environment "Variables={SAFESKY_API_KEY=$SAFESKY_API_KEY,CACHE_TTL=20,ALLOWED_ORIGIN=*}" \
        --timeout $TIMEOUT \
        --memory-size $MEMORY
else
    echo "Creating new Lambda function..."
    
    # First create the function
    aws lambda create-function \
        --function-name $FUNCTION_NAME \
        --runtime $RUNTIME \
        --role arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/lambda-execution-role \
        --handler $HANDLER \
        --zip-file fileb://deployment-package.zip \
        --timeout $TIMEOUT \
        --memory-size $MEMORY \
        --environment "Variables={SAFESKY_API_KEY=$SAFESKY_API_KEY,CACHE_TTL=20,ALLOWED_ORIGIN=*}"
fi

# Clean up
rm deployment-package.zip

echo ""
echo "======================================"
echo "Lambda Function Deployed!"
echo "======================================"
echo ""
echo "Function Name: $FUNCTION_NAME"
echo "Region: $REGION"
echo ""
echo "Next steps:"
echo "1. Create an API Gateway manually in AWS Console"
echo "2. Link it to this Lambda function"
echo "3. Enable CORS in API Gateway"
echo "4. Deploy the API to a stage"
echo "5. Update your Flutter app with the API endpoint"