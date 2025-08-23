const https = require('https');
const querystring = require('querystring');

// Cache configuration
const CACHE_DURATION = 5000; // 5 seconds in milliseconds
const cache = new Map();

// SafeSky API configuration
const SAFESKY_API_BASE = 'https://sandbox-public-api.safesky.app'; // Start with sandbox
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
            console.error('SafeSky API key not configured');
            return {
                statusCode: 500,
                headers: corsHeaders,
                body: JSON.stringify({ error: 'SafeSky API key not configured' }),
            };
        }

        // Extract and validate viewport parameter
        const viewport = event.queryStringParameters?.viewport;
        if (!viewport) {
            return {
                statusCode: 400,
                headers: corsHeaders,
                body: JSON.stringify({ error: 'viewport parameter is required' }),
            };
        }

        // Validate viewport format (should be: south,west,north,east)
        const coords = viewport.split(',');
        if (coords.length !== 4) {
            return {
                statusCode: 400,
                headers: corsHeaders,
                body: JSON.stringify({ error: 'viewport must be in format: south,west,north,east' }),
            };
        }

        // Parse and validate coordinates
        const [south, west, north, east] = coords.map(coord => {
            const num = parseFloat(coord);
            if (isNaN(num) || num < -180 || num > 180) {
                throw new Error(`Invalid coordinate: ${coord}`);
            }
            return num;
        });

        // Validate viewport bounds
        if (south >= north || west >= east) {
            return {
                statusCode: 400,
                headers: corsHeaders,
                body: JSON.stringify({ error: 'Invalid viewport bounds' }),
            };
        }

        // Check cache first
        const cacheKey = `viewport:${viewport}`;
        const cachedData = cache.get(cacheKey);
        
        if (cachedData && (Date.now() - cachedData.timestamp) < CACHE_DURATION) {
            console.log('Returning cached data for viewport:', viewport);
            return {
                statusCode: 200,
                headers: {
                    ...corsHeaders,
                    'X-Cache': 'HIT',
                    'Cache-Control': `max-age=${Math.ceil((CACHE_DURATION - (Date.now() - cachedData.timestamp)) / 1000)}`,
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
            .filter(beacon => isBeaconRecent(beacon))
            .map(beacon => sanitizeBeacon(beacon));

        console.log(`Processed ${processedBeacons.length} beacons from ${beacons.length} total`);

        // Cache the result
        cache.set(cacheKey, {
            data: processedBeacons,
            timestamp: Date.now(),
        });

        // Clean up old cache entries
        cleanupCache();

        return {
            statusCode: 200,
            headers: {
                ...corsHeaders,
                'X-Cache': 'MISS',
                'Cache-Control': `max-age=${Math.ceil(CACHE_DURATION / 1000)}`,
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
            method: 'GET',
            headers: {
                'Content-Type': 'application/json',
                'x-api-key': SAFESKY_API_KEY,
                'User-Agent': 'CaptainVFR/1.0',
            },
            timeout: 25000, // 25 second timeout
        };

        const req = https.request(url, options, (res) => {
            let data = '';
            
            res.on('data', (chunk) => {
                data += chunk;
            });
            
            res.on('end', () => {
                try {
                    if (res.statusCode === 200) {
                        const beacons = JSON.parse(data);
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
    if (!beacon.latitude || !beacon.longitude) return false;
    
    return beacon.latitude >= south && 
           beacon.latitude <= north && 
           beacon.longitude >= west && 
           beacon.longitude <= east;
}

/**
 * Check if a beacon was updated recently (within last 60 seconds)
 * @param {Object} beacon - Beacon object
 * @returns {boolean} True if beacon is recent
 */
function isBeaconRecent(beacon) {
    if (!beacon.last_update) return false;
    
    const now = Math.floor(Date.now() / 1000);
    const beaconAge = now - beacon.last_update;
    
    return beaconAge <= 60; // 60 seconds maximum age
}

/**
 * Sanitize beacon data to ensure consistent format
 * @param {Object} beacon - Raw beacon object
 * @returns {Object} Sanitized beacon object
 */
function sanitizeBeacon(beacon) {
    return {
        id: String(beacon.id || ''),
        latitude: Number(beacon.latitude) || 0,
        longitude: Number(beacon.longitude) || 0,
        altitude: Number(beacon.altitude) || 0,
        altitude_accuracy: beacon.altitude_accuracy ? Number(beacon.altitude_accuracy) : null,
        accuracy: beacon.accuracy ? Number(beacon.accuracy) : null,
        call_sign: beacon.call_sign ? String(beacon.call_sign) : null,
        ground_speed: Number(beacon.ground_speed) || 0,
        course: Number(beacon.course) || 0,
        status: beacon.status ? String(beacon.status) : null,
        last_update: Number(beacon.last_update) || 0,
        turn_rate: beacon.turn_rate ? Number(beacon.turn_rate) : null,
        vertical_rate: beacon.vertical_rate ? Number(beacon.vertical_rate) : null,
        beacon_type: beacon.beacon_type ? String(beacon.beacon_type) : null,
        transponder_type: beacon.transponder_type ? String(beacon.transponder_type) : null,
        remarks: beacon.remarks ? String(beacon.remarks) : null,
    };
}

/**
 * Clean up old cache entries
 */
function cleanupCache() {
    const now = Date.now();
    const maxAge = CACHE_DURATION * 2; // Keep cache entries for double the cache duration
    
    for (const [key, value] of cache.entries()) {
        if (now - value.timestamp > maxAge) {
            cache.delete(key);
        }
    }
}

/**
 * Health check endpoint
 */
if (require.main === module) {
    // For local testing
    const testEvent = {
        httpMethod: 'GET',
        queryStringParameters: {
            viewport: '48.83161,2.41143,52.51745,6.37275'
        }
    };
    
    exports.handler(testEvent, {}).then(result => {
        console.log('Test result:', JSON.stringify(result, null, 2));
    });
}