#!/bin/bash

# One-time API Gateway setup script
# Run this once to create the API Gateway that connects to the Lambda function

set -e

echo "======================================"
echo "API Gateway Setup for SafeSky Lambda"
echo "======================================"

# Configuration
API_NAME="CaptainVFR-SafeSky-API"
FUNCTION_NAME="captainvfr-safesky-proxy"
STAGE_NAME="prod"
AWS_REGION=${AWS_REGION:-"eu-central-1"}
AWS_PROFILE=${AWS_PROFILE:-"default"}

# Get AWS account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo "AWS Account: $AWS_ACCOUNT_ID"
echo "AWS Region: $AWS_REGION"

# Check if API already exists
API_ID=$(aws apigateway get-rest-apis --query "items[?name=='$API_NAME'].id" --output text)

if [ ! -z "$API_ID" ]; then
    echo "API Gateway already exists with ID: $API_ID"
    echo "API Endpoint: https://$API_ID.execute-api.$AWS_REGION.amazonaws.com/$STAGE_NAME/beacons"
    exit 0
fi

# Create REST API
echo "Creating REST API..."
API_ID=$(aws apigateway create-rest-api \
    --name "$API_NAME" \
    --description "REST API for SafeSky beacon data proxy" \
    --endpoint-configuration types=REGIONAL \
    --query 'id' \
    --output text)

echo "Created API with ID: $API_ID"

# Get root resource ID
ROOT_ID=$(aws apigateway get-resources \
    --rest-api-id $API_ID \
    --query 'items[0].id' \
    --output text)

# Create /beacons resource
echo "Creating /beacons resource..."
RESOURCE_ID=$(aws apigateway create-resource \
    --rest-api-id $API_ID \
    --parent-id $ROOT_ID \
    --path-part "beacons" \
    --query 'id' \
    --output text)

# Create GET method
echo "Creating GET method..."
aws apigateway put-method \
    --rest-api-id $API_ID \
    --resource-id $RESOURCE_ID \
    --http-method GET \
    --authorization-type NONE

# Create Lambda integration
echo "Creating Lambda integration..."
LAMBDA_ARN="arn:aws:lambda:$AWS_REGION:$AWS_ACCOUNT_ID:function:$FUNCTION_NAME"

aws apigateway put-integration \
    --rest-api-id $API_ID \
    --resource-id $RESOURCE_ID \
    --http-method GET \
    --type AWS_PROXY \
    --integration-http-method POST \
    --uri "arn:aws:apigateway:$AWS_REGION:lambda:path/2015-03-31/functions/$LAMBDA_ARN/invocations"

# Create OPTIONS method for CORS
echo "Creating OPTIONS method for CORS..."
aws apigateway put-method \
    --rest-api-id $API_ID \
    --resource-id $RESOURCE_ID \
    --http-method OPTIONS \
    --authorization-type NONE

# Mock integration for OPTIONS
aws apigateway put-integration \
    --rest-api-id $API_ID \
    --resource-id $RESOURCE_ID \
    --http-method OPTIONS \
    --type MOCK \
    --request-templates '{"application/json": "{\"statusCode\": 200}"}'

# Method responses for OPTIONS
aws apigateway put-method-response \
    --rest-api-id $API_ID \
    --resource-id $RESOURCE_ID \
    --http-method OPTIONS \
    --status-code 200 \
    --response-parameters '{
        "method.response.header.Access-Control-Allow-Headers": false,
        "method.response.header.Access-Control-Allow-Methods": false,
        "method.response.header.Access-Control-Allow-Origin": false
    }'

# Integration response for OPTIONS
aws apigateway put-integration-response \
    --rest-api-id $API_ID \
    --resource-id $RESOURCE_ID \
    --http-method OPTIONS \
    --status-code 200 \
    --response-parameters '{
        "method.response.header.Access-Control-Allow-Headers": "'"'"'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"'"'",
        "method.response.header.Access-Control-Allow-Methods": "'"'"'GET,OPTIONS'"'"'",
        "method.response.header.Access-Control-Allow-Origin": "'"'"'*'"'"'"
    }'

# Add Lambda permission for API Gateway
echo "Adding Lambda permission for API Gateway..."
aws lambda add-permission \
    --function-name $FUNCTION_NAME \
    --statement-id apigateway-invoke-$API_ID \
    --action lambda:InvokeFunction \
    --principal apigateway.amazonaws.com \
    --source-arn "arn:aws:execute-api:$AWS_REGION:$AWS_ACCOUNT_ID:$API_ID/*/*/*" \
    2>/dev/null || true

# Deploy API to stage
echo "Deploying API to $STAGE_NAME stage..."
aws apigateway create-deployment \
    --rest-api-id $API_ID \
    --stage-name $STAGE_NAME \
    --description "Initial deployment"

# Output the endpoint
API_ENDPOINT="https://$API_ID.execute-api.$AWS_REGION.amazonaws.com/$STAGE_NAME/beacons"

echo ""
echo "======================================"
echo "API Gateway Setup Complete!"
echo "======================================"
echo "API ID: $API_ID"
echo "API Endpoint: $API_ENDPOINT"
echo ""
echo "Test your API with:"
echo "curl \"$API_ENDPOINT?lat=46.9&lon=7.4&alt=500\""
echo ""
echo "Update your Flutter app with this endpoint in:"
echo "lib/services/safesky_service.dart"