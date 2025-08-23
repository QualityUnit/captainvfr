# Amplify CI/CD Setup for SafeSky Lambda

## Overview
This guide explains how to set up automatic Lambda deployment with each git push to the main branch monitored by your Amplify app (`d3v30q4rxj6okg`).

## Prerequisites

### 1. Amplify Service Role Permissions
Your Amplify app needs permissions to deploy Lambda functions. Add these permissions to your Amplify service role:

1. Go to AWS Amplify Console → Your App → App settings → General
2. Find the **Service role** (e.g., `amplifyconsole-backend-role`)
3. Click the role name to open IAM Console
4. Add the following inline policy:

```json
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
                "lambda:AddPermission"
            ],
            "Resource": "arn:aws:lambda:*:*:function:captainvfr-safesky-proxy"
        },
        {
            "Effect": "Allow",
            "Action": [
                "iam:CreateRole",
                "iam:GetRole",
                "iam:AttachRolePolicy",
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
        }
    ]
}
```

### 2. Set Environment Variables in Amplify Console

1. Go to AWS Amplify Console → Your App → App settings → Environment variables
2. Add:
   - **SAFESKY_API_KEY**: Your SafeSky API key (get from https://www.safesky.app/)
   - **AWS_REGION**: Your AWS region (e.g., `eu-central-1`)

## One-Time Setup

### Step 1: Create API Gateway (Run Once)
API Gateway needs to be created once. Run this locally:

```bash
cd backend/lambda/safesky-proxy
./setup-api-gateway.sh
```

This will output your API endpoint. Save it!

### Step 2: Update Flutter App
Update the API endpoint in your Flutter app:

```dart
// lib/services/safesky_service.dart
static const String _baseUrl = 'https://YOUR-API-ID.execute-api.REGION.amazonaws.com/prod';
```

## Automatic Deployment Process

With the setup complete, here's what happens on each git push:

1. **You push to main branch:**
   ```bash
   git add .
   git commit -m "Update SafeSky Lambda function"
   git push origin main
   ```

2. **Amplify automatically:**
   - Detects the push to main branch
   - Runs the backend build phase (deploys/updates Lambda)
   - Runs the frontend build phase (builds Hugo site)
   - Deploys everything

3. **Lambda deployment script (`amplify-deploy.sh`):**
   - Creates IAM role if needed
   - Creates or updates Lambda function
   - Sets environment variables (including SAFESKY_API_KEY)
   - Publishes new version

## Monitoring Deployments

### View Build Logs
1. Go to AWS Amplify Console → Your App
2. Click on the latest build
3. Check "Backend" phase for Lambda deployment logs

### View Lambda Logs
1. Go to AWS Lambda Console → `captainvfr-safesky-proxy`
2. Click "Monitor" tab → "View logs in CloudWatch"

## Testing After Deployment

Test your API endpoint:
```bash
curl "https://YOUR-API-ID.execute-api.REGION.amazonaws.com/prod/beacons?lat=46.9&lon=7.4&alt=500"
```

## Troubleshooting

### Build Fails with Permission Error
- Check Amplify service role has the required permissions (see above)

### Lambda Returns Mock Data
- Verify `SAFESKY_API_KEY` is set in Amplify environment variables

### API Gateway Not Found
- Run `./setup-api-gateway.sh` once to create it

### CORS Errors
- API Gateway CORS is configured in the setup script
- Lambda also returns CORS headers

## File Structure

```
backend/lambda/safesky-proxy/
├── index.js                 # Lambda function code
├── package.json             # Node.js configuration
├── amplify-deploy.sh        # CI/CD deployment script (runs on each push)
├── setup-api-gateway.sh     # One-time API Gateway setup
└── AMPLIFY_CICD_SETUP.md    # This documentation

amplify.yml                  # Amplify build configuration (updated)
```

## Cost Impact

Additional costs from CI/CD:
- Lambda deployments: Negligible (< $0.01/month)
- Build minutes: Minimal increase (~30 seconds per build)
- Total additional cost: < $0.50/month

## Security Notes

1. **API Key Security**: Stored in Amplify environment variables, never in code
2. **IAM Principle**: Least privilege - Lambda role only has basic execution permissions
3. **CORS**: Currently allows all origins (`*`), restrict in production

## Next Steps

1. ✅ Service role permissions configured
2. ✅ Environment variables set
3. ✅ API Gateway created (one-time)
4. ✅ Flutter app updated with endpoint
5. ✅ Push to main branch to test automatic deployment