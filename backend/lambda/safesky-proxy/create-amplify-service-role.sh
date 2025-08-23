#!/bin/bash

# Script to create and configure Amplify service role for Lambda deployment

set -e

echo "======================================"
echo "Creating Amplify Service Role"
echo "======================================"

ROLE_NAME="amplify-captainvfr-service-role"
PROFILE="default"
REGION="eu-central-1"
APP_ID="d3v30q4rxj6okg"

# Create trust policy for Amplify
cat > trust-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "amplify.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

# Create the IAM role
echo "Creating IAM role: $ROLE_NAME"
aws iam create-role \
    --profile $PROFILE \
    --role-name $ROLE_NAME \
    --assume-role-policy-document file://trust-policy.json \
    --description "Service role for Amplify app captainvfr to deploy Lambda functions" \
    2>/dev/null || echo "Role already exists"

# Create policy for Lambda deployment
cat > lambda-deploy-policy.json << 'EOF'
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "lambda:CreateFunction",
                "lambda:UpdateFunctionCode",
                "lambda:UpdateFunctionConfiguration",
                "lambda:GetFunction",
                "lambda:PublishVersion",
                "lambda:AddPermission",
                "lambda:RemovePermission",
                "lambda:InvokeFunction"
            ],
            "Resource": "arn:aws:lambda:*:*:function:captainvfr-safesky-proxy"
        },
        {
            "Effect": "Allow",
            "Action": [
                "iam:CreateRole",
                "iam:GetRole",
                "iam:AttachRolePolicy",
                "iam:PutRolePolicy",
                "iam:PassRole"
            ],
            "Resource": "arn:aws:iam::*:role/captainvfr-lambda-role"
        },
        {
            "Effect": "Allow",
            "Action": [
                "apigateway:GET",
                "apigateway:POST",
                "apigateway:PUT",
                "apigateway:DELETE"
            ],
            "Resource": "arn:aws:apigateway:*::/restapis/*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": "arn:aws:logs:*:*:*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "s3:GetObject",
                "s3:PutObject",
                "s3:ListBucket"
            ],
            "Resource": [
                "arn:aws:s3:::amplify-*/*",
                "arn:aws:s3:::amplify-*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": "sts:GetCallerIdentity",
            "Resource": "*"
        }
    ]
}
EOF

# Create and attach the policy
echo "Creating and attaching Lambda deployment policy..."
aws iam put-role-policy \
    --profile $PROFILE \
    --role-name $ROLE_NAME \
    --policy-name LambdaDeploymentPolicy \
    --policy-document file://lambda-deploy-policy.json

# Attach AWS managed policy for Amplify
echo "Attaching Amplify managed policy..."
aws iam attach-role-policy \
    --profile $PROFILE \
    --role-name $ROLE_NAME \
    --policy-arn arn:aws:iam::aws:policy/AdministratorAccess-Amplify

# Get the role ARN
ROLE_ARN=$(aws iam get-role --profile $PROFILE --role-name $ROLE_NAME --query 'Role.Arn' --output text)

echo ""
echo "Service role created: $ROLE_ARN"
echo ""

# Update Amplify app with the service role
echo "Updating Amplify app with service role..."
aws amplify update-app \
    --profile $PROFILE \
    --region $REGION \
    --app-id $APP_ID \
    --iam-service-role-arn $ROLE_ARN

# Clean up temporary files
rm -f trust-policy.json lambda-deploy-policy.json

echo ""
echo "======================================"
echo "Service Role Setup Complete!"
echo "======================================"
echo "Role Name: $ROLE_NAME"
echo "Role ARN: $ROLE_ARN"
echo "Amplify App: $APP_ID"
echo ""
echo "Your Amplify app now has permissions to deploy Lambda functions!"
echo ""
echo "Next steps:"
echo "1. Set SAFESKY_API_KEY in Amplify Console environment variables"
echo "2. Run ./setup-api-gateway.sh to create the API Gateway"
echo "3. Push to main branch to trigger automatic Lambda deployment"