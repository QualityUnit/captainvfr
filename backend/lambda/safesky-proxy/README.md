# SafeSky Proxy Lambda Function

This AWS Lambda function serves as a proxy for the SafeSky API, providing secure access to aircraft beacon data for the CaptainVFR mobile application.

## Features

- **API Key Security**: Keeps the SafeSky API key secure on the server side
- **Response Caching**: Implements 20-second caching to reduce API calls and improve performance
- **Data Filtering**: Filters beacons by viewport bounds and recency
- **Error Handling**: Graceful degradation when SafeSky API is unavailable
- **CORS Support**: Enables cross-origin requests from the mobile app
- **Input Validation**: Validates viewport parameters and coordinates

## Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `SAFESKY_API_KEY` | SafeSky API key for authentication | Yes |
| `NODE_ENV` | Environment (development/production) | No |

## API Endpoints

### GET /beacons

Fetches aircraft beacon data for a specified viewport.

**Parameters:**
- `viewport` (required): Comma-separated viewport bounds in format `south,west,north,east`

**Example:**
```
GET /beacons?viewport=48.83161,2.41143,52.51745,6.37275
```

**Response:**
```json
[
  {
    "id": "39D300",
    "latitude": 41.27638,
    "longitude": -8.68863,
    "altitude": 150,
    "altitude_accuracy": 0,
    "accuracy": 0,
    "call_sign": "TVF70DB",
    "ground_speed": 75,
    "course": 169,
    "status": "AIRBORNE",
    "last_update": 1708102018,
    "turn_rate": null,
    "vertical_rate": -3,
    "beacon_type": "JET",
    "transponder_type": "ADS-B",
    "remarks": null
  }
]
```

## Deployment

### Manual Deployment

1. Install dependencies (none currently):
   ```bash
   npm install
   ```

2. Create deployment package:
   ```bash
   npm run deploy
   ```

3. Upload `safesky-proxy.zip` to AWS Lambda

### AWS Amplify Deployment

Add to your `amplify.yml`:

```yaml
version: 1
backend:
  phases:
    build:
      commands:
        - cd backend/lambda/safesky-proxy
        - npm install
        - zip -r ../../../safesky-proxy.zip index.js package.json
functions:
  - functionName: safeskyProxy
    runtime: nodejs18.x
    environment:
      SAFESKY_API_KEY: ${SAFESKY_API_KEY}
```

## Configuration

### Lambda Function Settings

- **Runtime**: Node.js 18.x
- **Memory**: 512 MB
- **Timeout**: 30 seconds
- **Environment Variables**: `SAFESKY_API_KEY`

### API Gateway Settings

- **Integration**: Lambda Proxy Integration
- **CORS**: Enabled for all origins
- **Rate Limiting**: 100 requests per second recommended
- **Caching**: Optional (function has built-in caching)

## Monitoring

The function logs the following events:
- Incoming requests with parameters
- Cache hits/misses
- SafeSky API response status
- Error conditions

Use CloudWatch to monitor:
- Function duration
- Error rates
- Memory usage
- Request counts

## Security Considerations

1. **API Key Protection**: SafeSky API key is stored in environment variables
2. **Input Validation**: All viewport parameters are validated
3. **Rate Limiting**: Recommended to implement API Gateway rate limiting
4. **CORS**: Configure appropriate origins in production
5. **Error Messages**: Sensitive error details only shown in development

## Testing

Test locally:
```bash
npm test
```

This runs a test request with sample viewport coordinates.

## Cache Strategy

- **Duration**: 20 seconds per viewport
- **Key Format**: `viewport:{south,west,north,east}`
- **Cleanup**: Automatic cleanup of expired entries
- **Headers**: Cache status indicated via `X-Cache` header

## Error Handling

The function implements graceful error handling:
- Network errors return empty beacon array
- API errors return empty beacon array
- Invalid parameters return 400 status
- Missing API key returns 500 status

This ensures the mobile app continues to function even when SafeSky API is unavailable.