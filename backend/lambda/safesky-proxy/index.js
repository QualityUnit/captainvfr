const https = require('https');
const querystring = require('querystring');

// Cache configuration
const CACHE_DURATION = 20000; // 20 seconds in milliseconds
const cache = new Map();

// SafeSky API configuration
const SAFESKY_API_HOST = process.env.SAFESKY_API_HOST || 'sandbox-public-api.safesky.app';
const SAFESKY_API_KEY = process.env.SAFESKY_API_KEY;

/**
 * AWS Lambda handler for SafeSky beacon data proxy
 * 
 * @param {Object} event - Lambda event object
 * @param {Object} context - Lambda context object
 * @returns {Object} HTTP response
 */
exports.handler = async (event, context) => {
    console.log('SafeSky Proxy Request:', JSON.stringify(event, null, 2));
    
    // Set up CORS headers
    const corsHeaders = {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
        'Access-Control-Allow-Methods': 'GET,OPTIONS',
        'Content-Type': 'application/json',
    };

    // Handle preflight OPTIONS request
    if (event.httpMethod === 'OPTIONS') {
        return {
            statusCode: 200,
            headers: corsHeaders,
            body: '',
        };
    }

    // Only allow GET requests
    if (event.httpMethod !== 'GET') {
        return {
            statusCode: 405,
            headers: corsHeaders,
            body: JSON.stringify({ error: 'Method not allowed' }),
        };
    }

    try {
        // Validate API key is configured
        if (!SAFESKY_API_KEY) {
            console.log('SAFESKY_API_KEY not configured, returning mock data');
            
            // Return mock data for development
            const mockData = generateMockBeacons();
            return {
                statusCode: 200,
                headers: corsHeaders,
                body: JSON.stringify(mockData),
            };
        }

        // Parse query parameters
        const params = event.queryStringParameters || {};
        const lat = parseFloat(params.lat);
        const lon = parseFloat(params.lon);
        const alt = parseFloat(params.alt);

        // Validate parameters
        if (isNaN(lat) || isNaN(lon) || isNaN(alt)) {
            return {
                statusCode: 400,
                headers: corsHeaders,
                body: JSON.stringify({ 
                    error: 'Invalid parameters',
                    message: 'lat, lon, and alt must be valid numbers'
                }),
            };
        }

        // Check cache
        const cacheKey = `${lat.toFixed(2)}_${lon.toFixed(2)}_${Math.floor(alt/100)}`;
        const cachedData = cache.get(cacheKey);
        
        if (cachedData && (Date.now() - cachedData.timestamp) < CACHE_DURATION) {
            console.log('Returning cached data for:', cacheKey);
            return {
                statusCode: 200,
                headers: { ...corsHeaders, 'X-Cache': 'HIT' },
                body: JSON.stringify(cachedData.data),
            };
        }

        // Call SafeSky API
        console.log('Calling SafeSky API...');
        const safeSkyData = await callSafeSkyAPI(lat, lon, alt);
        
        // Cache the response
        cache.set(cacheKey, {
            data: safeSkyData,
            timestamp: Date.now()
        });

        // Clean old cache entries if cache is too large
        if (cache.size > 100) {
            const oldestKey = cache.keys().next().value;
            cache.delete(oldestKey);
        }

        return {
            statusCode: 200,
            headers: { ...corsHeaders, 'X-Cache': 'MISS' },
            body: JSON.stringify(safeSkyData),
        };

    } catch (error) {
        console.error('Error processing request:', error);
        return {
            statusCode: 500,
            headers: corsHeaders,
            body: JSON.stringify({ 
                error: 'Internal server error',
                message: error.message 
            }),
        };
    }
};

/**
 * Call SafeSky API
 */
async function callSafeSkyAPI(lat, lon, alt) {
    return new Promise((resolve, reject) => {
        // Create viewport: minLat, minLon, maxLat, maxLon
        // Create a box around the given point (approximately 50km radius)
        const latOffset = 0.45; // ~50km at this latitude
        const lonOffset = 0.65; // ~50km at this latitude
        
        const minLat = (lat - latOffset).toFixed(5);
        const minLon = (lon - lonOffset).toFixed(5);
        const maxLat = (lat + latOffset).toFixed(5);
        const maxLon = (lon + lonOffset).toFixed(5);
        
        const viewport = `${minLat},${minLon},${maxLat},${maxLon}`;
        const params = querystring.stringify({
            viewport: viewport
        });

        const options = {
            hostname: SAFESKY_API_HOST,
            port: 443,
            path: `/v1/beacons?${params}`,
            method: 'GET',
            headers: {
                'x-api-key': SAFESKY_API_KEY,
                'Content-Type': 'application/json',
                'Accept': 'application/json',
            }
        };

        const req = https.request(options, (res) => {
            let data = '';

            res.on('data', (chunk) => {
                data += chunk;
            });

            res.on('end', () => {
                try {
                    const beacons = JSON.parse(data);
                    resolve(beacons);
                } catch (error) {
                    reject(new Error('Failed to parse SafeSky response'));
                }
            });
        });

        req.on('error', (error) => {
            reject(error);
        });

        req.end();
    });
}

/**
 * Generate mock beacon data for development
 */
function generateMockBeacons() {
    return [
        {
            id: 'MOCK001',
            latitude: 46.9479,
            longitude: 7.4474,
            altitude: 1500,
            track: 45,
            groundSpeed: 120,
            verticalSpeed: 2,
            type: 'glider',
            callsign: 'HB-1234',
            timestamp: Date.now()
        },
        {
            id: 'MOCK002',
            latitude: 46.9579,
            longitude: 7.4374,
            altitude: 2000,
            track: 180,
            groundSpeed: 150,
            verticalSpeed: -1,
            type: 'lightAircraft',
            callsign: 'HB-5678',
            timestamp: Date.now()
        },
        {
            id: 'MOCK003',
            latitude: 46.9379,
            longitude: 7.4574,
            altitude: 1800,
            track: 270,
            groundSpeed: 100,
            verticalSpeed: 0,
            type: 'paraglider',
            callsign: 'PARA-99',
            timestamp: Date.now()
        }
    ];
}