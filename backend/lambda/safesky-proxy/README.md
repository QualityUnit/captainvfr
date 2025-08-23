# SafeSky Proxy Lambda Function

This AWS Lambda function acts as a proxy for SafeSky API requests, providing secure access to real-time aircraft beacon data for the CaptainVFR mobile application.

## Features

- Proxies requests to SafeSky API with secure API key management
- Implements 20-second response caching for performance
- Returns mock data when API key is not configured (development mode)
- CORS support for mobile app access
- Input validation and error handling

## Deployment

### Manual Deployment

1. **Set up Lambda function:**
   ```bash
   ./deploy-simple.sh
   ```

2. **Create API Gateway:**
   ```bash
   ./setup-api-gateway.sh
   ```

3. **Set SafeSky API key:**
   - In AWS Lambda Console, add environment variable:
   - `SAFESKY_API_KEY`: Your SafeSky API key

### Files

- `index.js` - Lambda function code
- `package.json` - Node.js configuration
- `deploy-simple.sh` - Simple deployment script using AWS CLI
- `setup-api-gateway.sh` - API Gateway setup script
- `template.yaml` - AWS SAM template for automated deployment

## API Usage

```
GET /beacons?lat=46.9&lon=7.4&alt=500
```

### Parameters
- `lat` - Latitude (required)
- `lon` - Longitude (required)
- `alt` - Altitude in meters (required)

### Response
```json
[
  {
    "id": "beacon-id",
    "latitude": 46.9,
    "longitude": 7.4,
    "altitude": 500,
    "type": "glider",
    "callsign": "HB-XXX",
    "timestamp": 1234567890
  }
]
```

## Environment Variables

- `SAFESKY_API_KEY` - SafeSky API key (required for production)
- `CACHE_TTL` - Cache duration in seconds (default: 20)
- `ALLOWED_ORIGIN` - CORS allowed origin (default: *)

## Testing

The function returns mock data when `SAFESKY_API_KEY` is not set, making it easy to test during development.