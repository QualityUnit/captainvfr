const https = require('https');
const querystring = require('querystring');

// Cache configuration
const CACHE_DURATION = 10000; // 10 seconds for beacon data (balances freshness with API load)
const WEATHER_CACHE_DURATION = 1800000; // 30 minutes for weather data
const MAX_CACHE_ENTRIES = 2000; // Maximum cache entries to prevent memory issues
const cache = new Map();
const weatherCache = new Map();

// Rate limiting configuration
const RATE_LIMIT_WINDOW = 60000; // 1 minute window
const MAX_REQUESTS_PER_IP = 20; // 20 requests per minute per IP
const MAX_TOTAL_REQUESTS = 100; // 100 total requests per minute
const rateLimitMap = new Map();
let totalRequestCount = 0;
let lastResetTime = Date.now();

// SafeSky API configuration
const SAFESKY_API_BASE = process.env.SAFESKY_API_BASE || 'https://sandbox-public-api.safesky.app'; // Default to Sandbox API
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
 * AWS Lambda handler for SafeSky proxy (beacon and weather data)
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

    // Route to appropriate handler based on path
    const path = event.path || event.rawPath || '/';
    
    // Weather endpoints
    if (path.includes('/metar/')) {
        return handleMetarRequest(event, corsHeaders, clientIp);
    } else if (path.includes('/taf/')) {
        return handleTafRequest(event, corsHeaders, clientIp);
    } else if (path.includes('/weather/')) {
        return handleCombinedWeatherRequest(event, corsHeaders, clientIp);
    }
    
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

        // Validate geographic bounds
        if (south < -90 || south > 90 || north < -90 || north > 90) {
            return {
                statusCode: 400,
                headers: corsHeaders,
                body: JSON.stringify({ 
                    error: 'Invalid latitude values',
                    message: 'Latitude must be between -90 and 90 degrees'
                }),
            };
        }

        if (west < -180 || west > 180 || east < -180 || east > 180) {
            return {
                statusCode: 400,
                headers: corsHeaders,
                body: JSON.stringify({ 
                    error: 'Invalid longitude values',
                    message: 'Longitude must be between -180 and 180 degrees'
                }),
            };
        }

        if (south >= north) {
            return {
                statusCode: 400,
                headers: corsHeaders,
                body: JSON.stringify({ 
                    error: 'Invalid viewport bounds',
                    message: 'South latitude must be less than north latitude'
                }),
            };
        }

        // Check viewport size (prevent requesting too large areas)
        const latSpan = north - south;
        const lonSpan = Math.abs(east - west);
        const maxSpan = 10; // Maximum 10 degrees span

        if (latSpan > maxSpan || lonSpan > maxSpan) {
            return {
                statusCode: 400,
                headers: corsHeaders,
                body: JSON.stringify({ 
                    error: 'Viewport too large',
                    message: `Maximum viewport span is ${maxSpan} degrees`
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
        if (cache.size > MAX_CACHE_ENTRIES) {
            // Remove oldest 25% of entries
            const entriesToDelete = Math.floor(cache.size * 0.25);
            const keys = Array.from(cache.keys());
            for (let i = 0; i < entriesToDelete; i++) {
                cache.delete(keys[i]);
            }
            console.log(`Cleaned ${entriesToDelete} old cache entries`);
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
        // Log detailed error for debugging
        console.error('Error in SafeSky proxy:', {
            errorName: error.name,
            errorMessage: error.message,
            errorStack: error.stack,
            requestPath: event.path,
            queryParams: event.queryStringParameters
        });
        
        // Return user-friendly error response
        return {
            statusCode: 500,
            headers: corsHeaders,
            body: JSON.stringify({ 
                error: 'Internal server error',
                message: process.env.NODE_ENV === 'development' ? error.message : 'An error occurred processing your request',
                timestamp: new Date().toISOString()
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
            
            // Distinguish between different error types
            if (error.code === 'ENOTFOUND') {
                console.error('SafeSky API host not found');
            } else if (error.code === 'ETIMEDOUT') {
                console.error('SafeSky API request timed out');
            } else if (error.code === 'ECONNREFUSED') {
                console.error('SafeSky API connection refused');
            }
            
            // Return empty array to gracefully degrade, but log the specific error
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

/**
 * Handle METAR request for a specific ICAO code
 * @param {Object} event - Lambda event object
 * @param {Object} corsHeaders - CORS headers
 * @param {string} clientIp - Client IP address
 * @returns {Object} HTTP response
 */
async function handleMetarRequest(event, corsHeaders, clientIp) {
    // Extract ICAO code from path
    const pathParts = event.path ? event.path.split('/') : event.rawPath.split('/');
    const icao = pathParts[pathParts.length - 1]?.toUpperCase();
    
    if (!icao || icao.length !== 4) {
        return {
            statusCode: 400,
            headers: corsHeaders,
            body: JSON.stringify({ 
                error: 'Invalid ICAO code',
                message: 'ICAO code must be 4 characters (e.g., KJFK)'
            }),
        };
    }

    // Check rate limit
    if (!checkRateLimit(clientIp)) {
        const retryAfter = Math.ceil(RATE_LIMIT_WINDOW / 1000);
        return {
            statusCode: 429,
            headers: {
                ...corsHeaders,
                'Retry-After': String(retryAfter),
            },
            body: JSON.stringify({ 
                error: 'Too many requests',
                retryAfter: retryAfter
            }),
        };
    }

    try {
        // Check weather cache
        const cacheKey = `metar_${icao}`;
        const cachedData = weatherCache.get(cacheKey);
        const now = Date.now();
        
        if (cachedData && (now - cachedData.timestamp) < WEATHER_CACHE_DURATION) {
            console.log('Returning cached METAR for:', icao);
            return {
                statusCode: 200,
                headers: {
                    ...corsHeaders,
                    'X-Cache': 'HIT',
                    'X-Data-Source': 'SafeSky',
                    'Cache-Control': `max-age=${Math.ceil((WEATHER_CACHE_DURATION - (now - cachedData.timestamp)) / 1000)}`,
                },
                body: JSON.stringify(cachedData.data),
            };
        }

        // Fetch from SafeSky API
        console.log('Fetching METAR from SafeSky for:', icao);
        const metar = await fetchSafeSkyWeather('metar', icao);
        
        if (metar) {
            // Cache the data
            weatherCache.set(cacheKey, {
                data: metar,
                timestamp: now
            });

            // Clean up old cache entries
            cleanupWeatherCache();

            return {
                statusCode: 200,
                headers: {
                    ...corsHeaders,
                    'X-Cache': 'MISS',
                    'X-Data-Source': 'SafeSky',
                    'Cache-Control': `max-age=${Math.ceil(WEATHER_CACHE_DURATION / 1000)}`,
                },
                body: JSON.stringify(metar),
            };
        } else {
            return {
                statusCode: 404,
                headers: corsHeaders,
                body: JSON.stringify({ 
                    error: 'No METAR data available',
                    icao: icao
                }),
            };
        }
    } catch (error) {
        console.error('Error fetching METAR:', error);
        return {
            statusCode: 500,
            headers: corsHeaders,
            body: JSON.stringify({ 
                error: 'Internal server error',
                message: process.env.NODE_ENV === 'development' ? error.message : undefined
            }),
        };
    }
}

/**
 * Handle TAF request for a specific ICAO code
 * @param {Object} event - Lambda event object
 * @param {Object} corsHeaders - CORS headers
 * @param {string} clientIp - Client IP address
 * @returns {Object} HTTP response
 */
async function handleTafRequest(event, corsHeaders, clientIp) {
    // Extract ICAO code from path
    const pathParts = event.path ? event.path.split('/') : event.rawPath.split('/');
    const icao = pathParts[pathParts.length - 1]?.toUpperCase();
    
    if (!icao || icao.length !== 4) {
        return {
            statusCode: 400,
            headers: corsHeaders,
            body: JSON.stringify({ 
                error: 'Invalid ICAO code',
                message: 'ICAO code must be 4 characters (e.g., KJFK)'
            }),
        };
    }

    // Check rate limit
    if (!checkRateLimit(clientIp)) {
        const retryAfter = Math.ceil(RATE_LIMIT_WINDOW / 1000);
        return {
            statusCode: 429,
            headers: {
                ...corsHeaders,
                'Retry-After': String(retryAfter),
            },
            body: JSON.stringify({ 
                error: 'Too many requests',
                retryAfter: retryAfter
            }),
        };
    }

    try {
        // Check weather cache
        const cacheKey = `taf_${icao}`;
        const cachedData = weatherCache.get(cacheKey);
        const now = Date.now();
        
        if (cachedData && (now - cachedData.timestamp) < WEATHER_CACHE_DURATION) {
            console.log('Returning cached TAF for:', icao);
            return {
                statusCode: 200,
                headers: {
                    ...corsHeaders,
                    'X-Cache': 'HIT',
                    'X-Data-Source': 'SafeSky',
                    'Cache-Control': `max-age=${Math.ceil((WEATHER_CACHE_DURATION - (now - cachedData.timestamp)) / 1000)}`,
                },
                body: JSON.stringify(cachedData.data),
            };
        }

        // Fetch from SafeSky API
        console.log('Fetching TAF from SafeSky for:', icao);
        const taf = await fetchSafeSkyWeather('taf', icao);
        
        if (taf) {
            // Cache the data
            weatherCache.set(cacheKey, {
                data: taf,
                timestamp: now
            });

            // Clean up old cache entries
            cleanupWeatherCache();

            return {
                statusCode: 200,
                headers: {
                    ...corsHeaders,
                    'X-Cache': 'MISS',
                    'X-Data-Source': 'SafeSky',
                    'Cache-Control': `max-age=${Math.ceil(WEATHER_CACHE_DURATION / 1000)}`,
                },
                body: JSON.stringify(taf),
            };
        } else {
            return {
                statusCode: 404,
                headers: corsHeaders,
                body: JSON.stringify({ 
                    error: 'No TAF data available',
                    icao: icao
                }),
            };
        }
    } catch (error) {
        console.error('Error fetching TAF:', error);
        return {
            statusCode: 500,
            headers: corsHeaders,
            body: JSON.stringify({ 
                error: 'Internal server error',
                message: process.env.NODE_ENV === 'development' ? error.message : undefined
            }),
        };
    }
}

/**
 * Handle combined weather request (both METAR and TAF)
 * @param {Object} event - Lambda event object
 * @param {Object} corsHeaders - CORS headers
 * @param {string} clientIp - Client IP address
 * @returns {Object} HTTP response
 */
async function handleCombinedWeatherRequest(event, corsHeaders, clientIp) {
    // Extract ICAO code from path
    const pathParts = event.path ? event.path.split('/') : event.rawPath.split('/');
    const icao = pathParts[pathParts.length - 1]?.toUpperCase();
    
    if (!icao || icao.length !== 4) {
        return {
            statusCode: 400,
            headers: corsHeaders,
            body: JSON.stringify({ 
                error: 'Invalid ICAO code',
                message: 'ICAO code must be 4 characters (e.g., KJFK)'
            }),
        };
    }

    // Check rate limit (counts as 2 requests)
    if (!checkRateLimit(clientIp) || !checkRateLimit(clientIp)) {
        const retryAfter = Math.ceil(RATE_LIMIT_WINDOW / 1000);
        return {
            statusCode: 429,
            headers: {
                ...corsHeaders,
                'Retry-After': String(retryAfter),
            },
            body: JSON.stringify({ 
                error: 'Too many requests',
                retryAfter: retryAfter
            }),
        };
    }

    try {
        const now = Date.now();
        const result = {
            icao: icao,
            metar: null,
            taf: null,
            metarSource: null,
            tafSource: null,
            timestamp: now
        };

        // Check METAR cache
        const metarCacheKey = `metar_${icao}`;
        const cachedMetar = weatherCache.get(metarCacheKey);
        
        if (cachedMetar && (now - cachedMetar.timestamp) < WEATHER_CACHE_DURATION) {
            console.log('Using cached METAR for:', icao);
            result.metar = cachedMetar.data;
            result.metarSource = 'SafeSky-cached';
        } else {
            // Fetch fresh METAR
            const metar = await fetchSafeSkyWeather('metar', icao);
            if (metar) {
                result.metar = metar;
                result.metarSource = 'SafeSky';
                weatherCache.set(metarCacheKey, {
                    data: metar,
                    timestamp: now
                });
            }
        }

        // Check TAF cache
        const tafCacheKey = `taf_${icao}`;
        const cachedTaf = weatherCache.get(tafCacheKey);
        
        if (cachedTaf && (now - cachedTaf.timestamp) < WEATHER_CACHE_DURATION) {
            console.log('Using cached TAF for:', icao);
            result.taf = cachedTaf.data;
            result.tafSource = 'SafeSky-cached';
        } else {
            // Fetch fresh TAF
            const taf = await fetchSafeSkyWeather('taf', icao);
            if (taf) {
                result.taf = taf;
                result.tafSource = 'SafeSky';
                weatherCache.set(tafCacheKey, {
                    data: taf,
                    timestamp: now
                });
            }
        }

        // Clean up old cache entries
        cleanupWeatherCache();

        const hasCache = result.metarSource?.includes('cached') || result.tafSource?.includes('cached');

        return {
            statusCode: 200,
            headers: {
                ...corsHeaders,
                'X-Cache': hasCache ? 'PARTIAL' : 'MISS',
                'X-Data-Source': 'SafeSky',
                'Cache-Control': `max-age=${Math.ceil(WEATHER_CACHE_DURATION / 1000)}`,
            },
            body: JSON.stringify(result),
        };
    } catch (error) {
        console.error('Error fetching weather:', error);
        return {
            statusCode: 500,
            headers: corsHeaders,
            body: JSON.stringify({ 
                error: 'Internal server error',
                message: process.env.NODE_ENV === 'development' ? error.message : undefined
            }),
        };
    }
}

/**
 * Fetch weather data from SafeSky API
 * @param {string} type - 'metar' or 'taf'
 * @param {string} icao - ICAO airport code
 * @returns {Promise<Object|null>} Weather data or null
 */
async function fetchSafeSkyWeather(type, icao) {
    if (!SAFESKY_API_KEY) {
        console.warn('SAFESKY_API_KEY not configured, returning null');
        return null;
    }

    return new Promise((resolve) => {
        const path = `/v1/fis/${type}/${icao}`;
        
        const options = {
            hostname: new URL(SAFESKY_API_BASE).hostname,
            port: 443,
            path: path,
            method: 'GET',
            headers: {
                'x-api-key': SAFESKY_API_KEY,
                'Accept': 'application/json',
                'Content-Type': 'application/json',
            },
            timeout: 30000, // 30 second timeout for weather data
        };

        const req = https.request(options, (res) => {
            let data = '';

            res.on('data', (chunk) => {
                data += chunk;
            });

            res.on('end', () => {
                try {
                    if (res.statusCode === 200) {
                        // SafeSky returns raw METAR/TAF text, not JSON
                        const weatherData = data.trim();
                        console.log(`SafeSky API returned ${type.toUpperCase()} for ${icao}: ${weatherData}`);
                        
                        // Return the raw weather data as an object
                        const result = {
                            icao: icao,
                            raw: weatherData,
                            type: type.toUpperCase(),
                            timestamp: new Date().toISOString()
                        };
                        
                        resolve(result);
                    } else if (res.statusCode === 404) {
                        console.log(`No ${type.toUpperCase()} data available for ${icao}`);
                        resolve(null);
                    } else {
                        console.error(`SafeSky API error for ${type}: ${res.statusCode} - ${data}`);
                        resolve(null);
                    }
                } catch (error) {
                    console.error(`Error processing SafeSky ${type} response:`, error);
                    resolve(null);
                }
            });
        });

        req.on('error', (error) => {
            console.error(`Error fetching ${type} from SafeSky:`, error);
            resolve(null);
        });

        req.on('timeout', () => {
            console.error(`SafeSky ${type} request timeout`);
            req.destroy();
            resolve(null);
        });

        req.end();
    });
}

/**
 * Clean up old weather cache entries
 */
function cleanupWeatherCache() {
    if (weatherCache.size > 200) {
        // Remove oldest entries
        const entriesToDelete = weatherCache.size - 150;
        const keys = Array.from(weatherCache.keys());
        for (let i = 0; i < entriesToDelete; i++) {
            weatherCache.delete(keys[i]);
        }
        console.log(`Cleaned ${entriesToDelete} old weather cache entries`);
    }
}

// Local testing
if (require.main === module) {
    // Test beacon endpoint
    const testBeaconEvent = {
        httpMethod: 'GET',
        path: '/beacons',
        queryStringParameters: {
            viewport: '46.8,7.3,47.0,7.6'
        },
        requestContext: {
            identity: {
                sourceIp: '127.0.0.1'
            }
        }
    };
    
    // Test METAR endpoint
    const testMetarEvent = {
        httpMethod: 'GET',
        path: '/metar/KJFK',
        requestContext: {
            identity: {
                sourceIp: '127.0.0.1'
            }
        }
    };
    
    // Test TAF endpoint
    const testTafEvent = {
        httpMethod: 'GET',
        path: '/taf/KJFK',
        requestContext: {
            identity: {
                sourceIp: '127.0.0.1'
            }
        }
    };
    
    // Test combined weather endpoint
    const testWeatherEvent = {
        httpMethod: 'GET',
        path: '/weather/KJFK',
        requestContext: {
            identity: {
                sourceIp: '127.0.0.1'
            }
        }
    };
    
    // Run tests
    console.log('Testing beacon endpoint...');
    exports.handler(testBeaconEvent, {}).then(result => {
        console.log('Beacon result:', JSON.stringify(result, null, 2));
        
        console.log('\nTesting METAR endpoint...');
        return exports.handler(testMetarEvent, {});
    }).then(result => {
        console.log('METAR result:', JSON.stringify(result, null, 2));
        
        console.log('\nTesting TAF endpoint...');
        return exports.handler(testTafEvent, {});
    }).then(result => {
        console.log('TAF result:', JSON.stringify(result, null, 2));
        
        console.log('\nTesting combined weather endpoint...');
        return exports.handler(testWeatherEvent, {});
    }).then(result => {
        console.log('Weather result:', JSON.stringify(result, null, 2));
    }).catch(error => {
        console.error('Test error:', error);
    });
}