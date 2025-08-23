const https = require('https');
const querystring = require('querystring');

// Cache configuration
const CACHE_DURATION = 5000; // 5 seconds in milliseconds
const cache = new Map();

// Rate limiting configuration
const RATE_LIMIT_WINDOW = 60000; // 1 minute window
const MAX_REQUESTS_PER_IP = 20; // 20 requests per minute per IP
const MAX_TOTAL_REQUESTS = 100; // 100 total requests per minute
const rateLimitMap = new Map();
let totalRequestCount = 0;
let lastResetTime = Date.now();

// SafeSky API configuration
const SAFESKY_API_BASE = 'https://sandbox-public-api.safesky.app'; // Sandbox API
const SAFESKY_API_KEY = process.env.SAFESKY_API_KEY;

/**
 * Check and update rate limits
 * @param {string} clientIp - Client IP address
 * @returns {boolean} True if request is allowed, false if rate limited
 */
function checkRateLimit(clientIp) {
    const now = Date.now();
    
    // Reset counters if window has passed
    if (now - lastResetTime > RATE_LIMIT_WINDOW) {
        rateLimitMap.clear();
        totalRequestCount = 0;
        lastResetTime = now;
    }
    
    // Check global rate limit
    if (totalRequestCount >= MAX_TOTAL_REQUESTS) {
        return false;
    }
    
    // Check per-IP rate limit
    const ipRequests = rateLimitMap.get(clientIp) || 0;
    if (ipRequests >= MAX_REQUESTS_PER_IP) {
        return false;
    }
    
    // Update counters
    rateLimitMap.set(clientIp, ipRequests + 1);
    totalRequestCount++;
    
    return true;
}

/**
 * AWS Lambda handler for SafeSky beacon data proxy
 * 
 * @param {Object} event - Lambda event object
 * @param {Object} context - Lambda context object
 * @returns {Object} HTTP response
 */
exports.handler = async (event, context) => {
    console.log('SafeSky Proxy Request:', JSON.stringify(event, null, 2));
    
    // CORS headers for all responses
    const corsHeaders = {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type',
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

    // Extract client IP (from API Gateway)
    const clientIp = event.requestContext?.identity?.sourceIp || 'unknown';
    
    // Check rate limit
    if (!checkRateLimit(clientIp)) {
        const retryAfter = Math.ceil(RATE_LIMIT_WINDOW / 1000); // Convert to seconds
        return {
            statusCode: 429,
            headers: {
                ...corsHeaders,
                'Retry-After': String(retryAfter),
                'X-RateLimit-Limit': String(MAX_REQUESTS_PER_IP),
                'X-RateLimit-Remaining': '0',
                'X-RateLimit-Reset': String(Math.ceil((lastResetTime + RATE_LIMIT_WINDOW) / 1000)),
            },
            body: JSON.stringify({ 
                error: 'Too many requests',
                message: `Please wait ${retryAfter} seconds before making another request`,
                retryAfter: retryAfter
            }),
        };
    }

    try {
        // Check if API key is configured
        if (!SAFESKY_API_KEY) {
            console.warn('SAFESKY_API_KEY environment variable not set - API will return mock data');
            
            // Return mock data for development/testing
            const mockBeacons = generateMockBeacons();
            return {
                statusCode: 200,
                headers: {
                    ...corsHeaders,
                    'X-Cache': 'MOCK',
                    'X-RateLimit-Limit': String(MAX_REQUESTS_PER_IP),
                    'X-RateLimit-Remaining': String(MAX_REQUESTS_PER_IP - (rateLimitMap.get(clientIp) || 1)),
                },
                body: JSON.stringify(mockBeacons),
            };
        }

        // Parse viewport parameter (format: south,west,north,east)
        const viewport = event.queryStringParameters?.viewport;
        
        if (!viewport) {
            return {
                statusCode: 400,
                headers: corsHeaders,
                body: JSON.stringify({ 
                    error: 'Missing viewport parameter',
                    message: 'viewport parameter is required (format: south,west,north,east)'
                }),
            };
        }

        // Parse viewport bounds
        const [south, west, north, east] = viewport.split(',').map(parseFloat);
        
        if ([south, west, north, east].some(isNaN)) {
            return {
                statusCode: 400,
                headers: corsHeaders,
                body: JSON.stringify({ 
                    error: 'Invalid viewport parameter',
                    message: 'viewport must contain 4 comma-separated numbers (south,west,north,east)'
                }),
            };
        }

        // Create cache key based on viewport (rounded to reduce cache misses)
        const cacheKey = `${south.toFixed(2)}_${west.toFixed(2)}_${north.toFixed(2)}_${east.toFixed(2)}`;
        
        // Check cache
        const cachedData = cache.get(cacheKey);
        const now = Date.now();
        
        if (cachedData && (now - cachedData.timestamp) < CACHE_DURATION) {
            console.log('Returning cached data for viewport:', cacheKey);
            
            const remaining = MAX_REQUESTS_PER_IP - (rateLimitMap.get(clientIp) || 1);
            
            return {
                statusCode: 200,
                headers: {
                    ...corsHeaders,
                    'X-Cache': 'HIT',
                    'Cache-Control': `max-age=${Math.ceil((CACHE_DURATION - (now - cachedData.timestamp)) / 1000)}`,
                    'X-RateLimit-Limit': String(MAX_REQUESTS_PER_IP),
                    'X-RateLimit-Remaining': String(remaining),
                    'X-RateLimit-Reset': String(Math.ceil((lastResetTime + RATE_LIMIT_WINDOW) / 1000)),
                },
                body: JSON.stringify(cachedData.data),
            };
        }

        // Fetch data from SafeSky API
        console.log('Fetching fresh data from SafeSky API for viewport:', viewport);
        const beacons = await fetchSafeSkyBeacons(viewport);

        // Filter and process beacon data
        const processedBeacons = beacons
            .filter(beacon => beacon && beacon.id) // Remove invalid beacons
            .filter(beacon => isBeaconInViewport(beacon, south, west, north, east))
            .filter(beacon => isBeaconRecent(beacon)); // Only include recent beacons

        // Cache the processed data
        cache.set(cacheKey, {
            data: processedBeacons,
            timestamp: now
        });

        // Clean up old cache entries if cache grows too large
        if (cache.size > 100) {
            const oldestKey = cache.keys().next().value;
            cache.delete(oldestKey);
            console.log('Cleaned old cache entry:', oldestKey);
        }

        const remaining = MAX_REQUESTS_PER_IP - (rateLimitMap.get(clientIp) || 1);

        return {
            statusCode: 200,
            headers: {
                ...corsHeaders,
                'X-Cache': 'MISS',
                'Cache-Control': `max-age=${Math.ceil(CACHE_DURATION / 1000)}`,
                'X-RateLimit-Limit': String(MAX_REQUESTS_PER_IP),
                'X-RateLimit-Remaining': String(remaining),
                'X-RateLimit-Reset': String(Math.ceil((lastResetTime + RATE_LIMIT_WINDOW) / 1000)),
            },
            body: JSON.stringify(processedBeacons),
        };

    } catch (error) {
        console.error('Error in SafeSky proxy:', error);
        
        return {
            statusCode: 500,
            headers: corsHeaders,
            body: JSON.stringify({ 
                error: 'Internal server error',
                message: process.env.NODE_ENV === 'development' ? error.message : undefined
            }),
        };
    }
};

/**
 * Fetch beacon data from SafeSky API
 * @param {string} viewport - Viewport coordinates string
 * @returns {Promise<Array>} Array of beacon objects
 */
async function fetchSafeSkyBeacons(viewport) {
    return new Promise((resolve, reject) => {
        const url = `${SAFESKY_API_BASE}/v1/beacons/?viewport=${encodeURIComponent(viewport)}`;
        
        const options = {
            hostname: new URL(SAFESKY_API_BASE).hostname,
            port: 443,
            path: `/v1/beacons/?viewport=${encodeURIComponent(viewport)}`,
            method: 'GET',
            headers: {
                'x-api-key': SAFESKY_API_KEY,
                'Accept': 'application/json',
                'Content-Type': 'application/json',
            },
            timeout: 10000, // 10 second timeout
        };

        const req = https.request(options, (res) => {
            let data = '';

            res.on('data', (chunk) => {
                data += chunk;
            });

            res.on('end', () => {
                try {
                    if (res.statusCode === 200) {
                        const beacons = JSON.parse(data);
                        console.log(`SafeSky API returned ${beacons.length} beacons`);
                        resolve(Array.isArray(beacons) ? beacons : []);
                    } else {
                        console.error(`SafeSky API error: ${res.statusCode} - ${data}`);
                        // Return empty array on API errors to gracefully degrade
                        resolve([]);
                    }
                } catch (parseError) {
                    console.error('Error parsing SafeSky API response:', parseError);
                    resolve([]);
                }
            });
        });

        req.on('error', (error) => {
            console.error('Error making request to SafeSky API:', error);
            // Return empty array on network errors to gracefully degrade
            resolve([]);
        });

        req.on('timeout', () => {
            console.error('SafeSky API request timeout');
            req.destroy();
            resolve([]);
        });

        req.end();
    });
}

/**
 * Check if a beacon is within the specified viewport
 * @param {Object} beacon - Beacon object
 * @param {number} south - South boundary
 * @param {number} west - West boundary
 * @param {number} north - North boundary
 * @param {number} east - East boundary
 * @returns {boolean} True if beacon is in viewport
 */
function isBeaconInViewport(beacon, south, west, north, east) {
    return beacon.latitude >= south && 
           beacon.latitude <= north && 
           beacon.longitude >= west && 
           beacon.longitude <= east;
}

/**
 * Check if beacon data is recent (within last 60 seconds)
 * @param {Object} beacon - Beacon object
 * @returns {boolean} True if beacon is recent
 */
function isBeaconRecent(beacon) {
    if (!beacon.last_update) return true; // If no timestamp, assume it's recent
    
    const now = Math.floor(Date.now() / 1000); // Current time in seconds
    const age = now - beacon.last_update;
    
    return age <= 60; // Consider beacons older than 60 seconds as stale
}

/**
 * Generate mock beacon data for testing
 * @returns {Array} Array of mock beacon objects
 */
function generateMockBeacons() {
    const now = Math.floor(Date.now() / 1000);
    
    return [
        {
            id: 'MOCK001',
            latitude: 46.9479,
            longitude: 7.4474,
            altitude: 1500,
            call_sign: 'VFR123',
            ground_speed: 55,
            course: 90,
            status: 'AIRBORNE',
            last_update: now - 5,
            vertical_rate: 2,
            beacon_type: 'JET',
            transponder_type: 'ADS-B',
        },
        {
            id: 'MOCK002',
            latitude: 46.9579,
            longitude: 7.4374,
            altitude: 1200,
            call_sign: 'GLI456',
            ground_speed: 25,
            course: 180,
            status: 'AIRBORNE',
            last_update: now - 8,
            vertical_rate: 0,
            beacon_type: 'GLIDER',
        },
        {
            id: 'MOCK003',
            latitude: 46.9379,
            longitude: 7.4574,
            altitude: 500,
            call_sign: 'HELI99',
            ground_speed: 35,
            course: 270,
            status: 'AIRBORNE',
            last_update: now - 10,
            vertical_rate: -2,
            beacon_type: 'HELICOPTER',
            transponder_type: 'ADS-B',
        },
    ];
}

// Local testing
if (require.main === module) {
    const testEvent = {
        httpMethod: 'GET',
        queryStringParameters: {
            viewport: '46.8,7.3,47.0,7.6'
        },
        requestContext: {
            identity: {
                sourceIp: '127.0.0.1'
            }
        }
    };
    
    exports.handler(testEvent, {}).then(result => {
        console.log('Test result:', JSON.stringify(result, null, 2));
    });
}