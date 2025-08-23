# SafeSky Proxy Lambda Function

This AWS Lambda function serves as a proxy for the SafeSky API, providing secure access to aircraft beacon data for the CaptainVFR mobile application.

## Features

- **API Key Security**: Keeps the SafeSky API key secure on the server side
- **Response Caching**: Implements 5-second caching to reduce API calls and improve performance
- **Rate Limiting**: Enforces per-IP (20/min) and global (100/min) request limits
- **Data Filtering**: Filters beacons by viewport bounds and recency
- **Error Handling**: Graceful degradation when SafeSky API is unavailable
- **Mock Data**: Returns mock beacons for development when API key is not configured
- **CORS Support**: Configured for mobile app access

## API Endpoint

```
GET /beacons?viewport=south,west,north,east
```

### Parameters
- `viewport` (required): Comma-separated coordinates defining the viewport bounds
  - Format: `south,west,north,east`
  - Example: `46.8,7.3,47.0,7.6`

### Response Headers
- `X-Cache`: Indicates cache status (HIT/MISS/MOCK)
- `X-RateLimit-Limit`: Maximum requests allowed per minute
- `X-RateLimit-Remaining`: Remaining requests in current window
- `X-RateLimit-Reset`: Unix timestamp when rate limit resets
- `Retry-After`: Seconds to wait when rate limited (429 response)

### Response Format
```json
[
  {
    "id": "beacon-123",
    "latitude": 46.9479,
    "longitude": 7.4474,
    "altitude": 1500,
    "call_sign": "VFR123",
    "ground_speed": 55,
    "course": 90,
    "status": "AIRBORNE",
    "last_update": 1234567890,
    "turn_rate": null,
    "vertical_rate": 2,
    "beacon_type": "JET",
    "transponder_type": "ADS-B",
    "remarks": null
  }
]
```

## Deployment

### Manual Deployment

1. Install dependencies (none currently required):
   ```bash
   npm install
   ```

2. Create deployment package:
   ```bash
   npm run deploy
   ```

3. Deploy to AWS Lambda:
   ```bash
   ./deploy-simple.sh
   ```

4. Set up API Gateway:
   ```bash
   ./setup-api-gateway.sh
   ```

5. Configure environment variables in AWS Lambda Console:
   - `SAFESKY_API_KEY`: Your SafeSky API key (required for production)
   - `NODE_ENV`: Set to 'development' for verbose error messages

### AWS SAM Deployment

For automated deployment using AWS SAM:

```bash
sam build
sam deploy --guided
```

## Environment Variables

- `SAFESKY_API_KEY` - SafeSky API key (required for production)
- `NODE_ENV` - Environment mode (development/production)

## Rate Limiting

The function implements two-tier rate limiting:
- **Per-IP limit**: 20 requests per minute per client IP
- **Global limit**: 100 total requests per minute across all clients
- **Window**: 60-second sliding window
- **Exponential backoff**: Clients should respect Retry-After header

## Caching

- **Duration**: 5 seconds per viewport
- **Key**: Based on rounded viewport coordinates
- **Size limit**: Maximum 100 cached viewports
- **Automatic cleanup**: Oldest entries removed when limit exceeded

## Error Handling

The function implements graceful error handling:
- Network errors return empty beacon array
- API errors return empty beacon array  
- Invalid parameters return 400 status
- Rate limiting returns 429 status with retry information
- Missing API key returns mock data for development

This ensures the mobile app continues to function even when SafeSky API is unavailable.

## Testing

The function includes local testing capability:

```bash
node index.js
```

This will execute a test request and display the response.

## Security Considerations

- API key is stored as environment variable, never exposed to clients
- Rate limiting prevents abuse and excessive API usage
- Input validation ensures only valid viewport parameters are accepted
- CORS headers restrict access to authorized origins in production