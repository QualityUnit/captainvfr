# SafeSky Lambda Deployment Guide

## Your Current Setup
- **Amplify App ID**: `d3v30q4rxj6okg` (used for Hugo website hosting)
- **Lambda Function**: Needs separate deployment

## Deployment Options

### Option 1: AWS Console (Manual - Recommended for First Time)

#### Step 1: Deploy Lambda Function
1. Go to [AWS Lambda Console](https://console.aws.amazon.com/lambda/)
2. Click **"Create function"**
3. Configure:
   - **Function name**: `captainvfr-safesky-proxy`
   - **Runtime**: Node.js 20.x
   - **Architecture**: x86_64
4. Click **"Create function"**
5. In the Code tab, click **"Upload from"** → **".zip file"**
6. Upload the deployment package:
   ```bash
   cd backend/lambda/safesky-proxy
   zip deployment-package.zip index.js package.json
   # Upload deployment-package.zip
   ```

#### Step 2: Configure Lambda
1. Go to **Configuration** → **General configuration**:
   - Timeout: 30 seconds
   - Memory: 512 MB
2. Go to **Configuration** → **Environment variables**:
   - Add `SAFESKY_API_KEY`: Your SafeSky API key
   - Add `CACHE_TTL`: 20
   - Add `ALLOWED_ORIGIN`: *

#### Step 3: Create API Gateway
1. Go to [API Gateway Console](https://console.aws.amazon.com/apigateway/)
2. Click **"Create API"** → **"REST API"** → **"Build"**
3. Configure:
   - **API name**: `CaptainVFR-SafeSky-API`
   - **Endpoint Type**: Regional
4. Create resource:
   - Click **"Actions"** → **"Create Resource"**
   - **Resource Name**: beacons
   - **Resource Path**: /beacons
5. Create GET method:
   - Select `/beacons`
   - **Actions** → **"Create Method"** → **GET**
   - **Integration type**: Lambda Function
   - **Lambda Function**: captainvfr-safesky-proxy
   - **Use Lambda Proxy integration**: ✅
6. Enable CORS:
   - Select `/beacons`
   - **Actions** → **"Enable CORS"**
   - Use default settings
7. Deploy API:
   - **Actions** → **"Deploy API"**
   - **Stage**: prod
   - Note the **Invoke URL**

### Option 2: AWS CLI (Automated)

```bash
cd backend/lambda/safesky-proxy
./deploy-simple.sh
```

Then manually create API Gateway in console (Steps 3 above).

### Option 3: AWS SAM (Full Automation)

First install SAM CLI:
```bash
brew install aws-sam-cli  # macOS
```

Then deploy:
```bash
cd backend/lambda/safesky-proxy
./deploy.sh
```

## Testing Your Deployment

Once deployed, test the API:

```bash
# Replace with your actual API Gateway URL
curl "https://YOUR-API-ID.execute-api.REGION.amazonaws.com/prod/beacons?lat=46.9&lon=7.4&alt=500"
```

Expected response:
```json
[
  {
    "id": "mock-1",
    "latitude": 46.95,
    "longitude": 7.35,
    "altitude": 600,
    "type": "glider",
    "callsign": "MOCK1"
  }
]
```

## Update Flutter App

After deployment, update the API URL in your Flutter app:

```dart
// File: lib/services/safesky_service.dart
// Line 13
static const String _baseUrl = 'https://YOUR-API-ID.execute-api.REGION.amazonaws.com/prod';
```

## API Endpoint Format

Your API endpoint will be:
```
https://[API-ID].execute-api.[REGION].amazonaws.com/prod/beacons
```

Example:
```
https://abc123xyz.execute-api.us-east-1.amazonaws.com/prod/beacons
```

## Troubleshooting

### Function returns mock data
- Verify `SAFESKY_API_KEY` environment variable is set
- Check CloudWatch logs for errors

### CORS errors in app
- Ensure CORS is enabled in API Gateway
- Verify OPTIONS method is configured

### API Gateway 5xx errors
- Check Lambda function timeout (should be 30s)
- Verify Lambda has basic execution role

## Cost Estimate

For typical usage (10,000 requests/month):
- Lambda: ~$0.50/month
- API Gateway: ~$0.035/month
- **Total: <$1/month**

## Security Notes

1. **API Key**: Store SafeSky API key in environment variables, never in code
2. **CORS**: Restrict `ALLOWED_ORIGIN` to your app domain in production
3. **Rate Limiting**: Consider adding API Gateway throttling
4. **Monitoring**: Set up CloudWatch alarms for errors

## Next Steps

1. Deploy the Lambda function using one of the methods above
2. Test the API endpoint
3. Update Flutter app with the endpoint
4. Test in the mobile app
5. Monitor CloudWatch logs for any issues