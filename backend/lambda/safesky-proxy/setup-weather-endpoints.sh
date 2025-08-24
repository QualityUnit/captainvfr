#!/bin/bash

# Configuration
API_ID="imuwdhmbde"
REGION="eu-central-1"
LAMBDA_ARN="arn:aws:lambda:eu-central-1:444348080366:function:captainvfr-safesky-proxy"
ROOT_ID="qg6jeicsc3"

echo "Setting up weather endpoints in API Gateway..."

# Create /metar resource
echo "Creating /metar resource..."
METAR_RESOURCE=$(aws apigateway create-resource \
    --rest-api-id $API_ID \
    --parent-id $ROOT_ID \
    --path-part "metar" \
    --region $REGION \
    --query 'id' \
    --output text)

# Create /metar/{icao} resource
echo "Creating /metar/{icao} resource..."
METAR_ICAO_RESOURCE=$(aws apigateway create-resource \
    --rest-api-id $API_ID \
    --parent-id $METAR_RESOURCE \
    --path-part "{icao}" \
    --region $REGION \
    --query 'id' \
    --output text)

# Create /taf resource
echo "Creating /taf resource..."
TAF_RESOURCE=$(aws apigateway create-resource \
    --rest-api-id $API_ID \
    --parent-id $ROOT_ID \
    --path-part "taf" \
    --region $REGION \
    --query 'id' \
    --output text)

# Create /taf/{icao} resource
echo "Creating /taf/{icao} resource..."
TAF_ICAO_RESOURCE=$(aws apigateway create-resource \
    --rest-api-id $API_ID \
    --parent-id $TAF_RESOURCE \
    --path-part "{icao}" \
    --region $REGION \
    --query 'id' \
    --output text)

# Create /weather resource
echo "Creating /weather resource..."
WEATHER_RESOURCE=$(aws apigateway create-resource \
    --rest-api-id $API_ID \
    --parent-id $ROOT_ID \
    --path-part "weather" \
    --region $REGION \
    --query 'id' \
    --output text)

# Create /weather/{icao} resource
echo "Creating /weather/{icao} resource..."
WEATHER_ICAO_RESOURCE=$(aws apigateway create-resource \
    --rest-api-id $API_ID \
    --parent-id $WEATHER_RESOURCE \
    --path-part "{icao}" \
    --region $REGION \
    --query 'id' \
    --output text)

# Setup GET method for /metar/{icao}
echo "Setting up GET method for /metar/{icao}..."
aws apigateway put-method \
    --rest-api-id $API_ID \
    --resource-id $METAR_ICAO_RESOURCE \
    --http-method GET \
    --authorization-type NONE \
    --region $REGION

aws apigateway put-integration \
    --rest-api-id $API_ID \
    --resource-id $METAR_ICAO_RESOURCE \
    --http-method GET \
    --type AWS_PROXY \
    --integration-http-method POST \
    --uri "arn:aws:apigateway:$REGION:lambda:path/2015-03-31/functions/$LAMBDA_ARN/invocations" \
    --region $REGION

# Setup GET method for /taf/{icao}
echo "Setting up GET method for /taf/{icao}..."
aws apigateway put-method \
    --rest-api-id $API_ID \
    --resource-id $TAF_ICAO_RESOURCE \
    --http-method GET \
    --authorization-type NONE \
    --region $REGION

aws apigateway put-integration \
    --rest-api-id $API_ID \
    --resource-id $TAF_ICAO_RESOURCE \
    --http-method GET \
    --type AWS_PROXY \
    --integration-http-method POST \
    --uri "arn:aws:apigateway:$REGION:lambda:path/2015-03-31/functions/$LAMBDA_ARN/invocations" \
    --region $REGION

# Setup GET method for /weather/{icao}
echo "Setting up GET method for /weather/{icao}..."
aws apigateway put-method \
    --rest-api-id $API_ID \
    --resource-id $WEATHER_ICAO_RESOURCE \
    --http-method GET \
    --authorization-type NONE \
    --region $REGION

aws apigateway put-integration \
    --rest-api-id $API_ID \
    --resource-id $WEATHER_ICAO_RESOURCE \
    --http-method GET \
    --type AWS_PROXY \
    --integration-http-method POST \
    --uri "arn:aws:apigateway:$REGION:lambda:path/2015-03-31/functions/$LAMBDA_ARN/invocations" \
    --region $REGION

# Setup OPTIONS (CORS) for each endpoint
for RESOURCE_ID in $METAR_ICAO_RESOURCE $TAF_ICAO_RESOURCE $WEATHER_ICAO_RESOURCE; do
    echo "Setting up CORS for resource $RESOURCE_ID..."
    aws apigateway put-method \
        --rest-api-id $API_ID \
        --resource-id $RESOURCE_ID \
        --http-method OPTIONS \
        --authorization-type NONE \
        --region $REGION
    
    aws apigateway put-integration \
        --rest-api-id $API_ID \
        --resource-id $RESOURCE_ID \
        --http-method OPTIONS \
        --type AWS_PROXY \
        --integration-http-method POST \
        --uri "arn:aws:apigateway:$REGION:lambda:path/2015-03-31/functions/$LAMBDA_ARN/invocations" \
        --region $REGION
done

# Deploy the API
echo "Deploying API to prod stage..."
aws apigateway create-deployment \
    --rest-api-id $API_ID \
    --stage-name prod \
    --region $REGION

echo "API Gateway setup complete!"
echo "API Endpoint: https://$API_ID.execute-api.$REGION.amazonaws.com/prod"
echo ""
echo "Test endpoints:"
echo "  https://$API_ID.execute-api.$REGION.amazonaws.com/prod/metar/KJFK"
echo "  https://$API_ID.execute-api.$REGION.amazonaws.com/prod/taf/KJFK"
echo "  https://$API_ID.execute-api.$REGION.amazonaws.com/prod/weather/KJFK"
