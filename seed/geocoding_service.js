// geocoding_service.js
// Converts Colombian addresses to precise coordinates using Google Geocoding API
import { readFileSync, writeFileSync, existsSync } from "fs";
import dotenv from "dotenv";

// Load environment variables from .env file
const envResult = dotenv.config();

// Debug: Check if .env was loaded
if (envResult.error) {
  console.warn("⚠️  Warning: Could not load .env file. Geocoding will use fallback coordinates.");
  console.warn("   Create a .env file with GOOGLE_MAPS_API_KEY to enable precise geocoding.");
}

// ===================== CONFIGURATION =====================
const GEOCODING_CONFIG = {
  apiKey: process.env.GOOGLE_MAPS_API_KEY || null,
  enabled: !!(process.env.GOOGLE_MAPS_API_KEY && process.env.GOOGLE_MAPS_API_KEY.trim()),
  cacheFile: "geocoding_cache.json",
  requestDelayMs: 200,
  maxRetries: 3,
  retryDelayMs: 1000,
  defaultLocation: {
    lat: 4.6533,
    lon: -74.0836,
  },
};

// Debug log on startup
if (GEOCODING_CONFIG.enabled) {
  console.log("✅ Geocoding API enabled");
  console.log(`   API Key: ${GEOCODING_CONFIG.apiKey.substring(0, 10)}...`);
} else {
  console.log("ℹ️  Geocoding API disabled - using localidad-based coordinates");
  console.log("   To enable: Add GOOGLE_MAPS_API_KEY to .env file");
}

// ...rest of your code...

// ===================== CACHE MANAGEMENT =====================
let geocodingCache = {};

/**
 * Load geocoding cache from file
 */
function loadCache() {
  if (existsSync(GEOCODING_CONFIG.cacheFile)) {
    try {
      const data = readFileSync(GEOCODING_CONFIG.cacheFile, "utf8");
      geocodingCache = JSON.parse(data);
      console.log(`   📂 Loaded ${Object.keys(geocodingCache).length} cached addresses`);
    } catch (error) {
      console.warn("   ⚠️  Error loading cache, starting fresh:", error.message);
      geocodingCache = {};
    }
  }
}

/**
 * Save geocoding cache to file
 */
function saveCache() {
  try {
    writeFileSync(
      GEOCODING_CONFIG.cacheFile,
      JSON.stringify(geocodingCache, null, 2),
      "utf8"
    );
    console.log(`   💾 Saved ${Object.keys(geocodingCache).length} addresses to cache`);
  } catch (error) {
    console.error("   ❌ Error saving cache:", error.message);
  }
}

/**
 * Get cache key for an address
 */
function getCacheKey(address, city) {
  return `${address}, ${city}, Colombia`.toLowerCase().trim();
}

// ===================== GEOCODING FUNCTIONS =====================

/**
 * Sleep utility for rate limiting
 */
function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

/**
 * Geocode a single address using Google Geocoding API
 */
async function geocodeAddress(address, city = "Bogotá", attempt = 1) {
  const cacheKey = getCacheKey(address, city);
  
  // Check cache first
  if (geocodingCache[cacheKey]) {
    return geocodingCache[cacheKey];
  }
  
  // Check if API key is configured
  if (!GEOCODING_CONFIG.apiKey || GEOCODING_CONFIG.apiKey === "") {
    if (attempt === 1) { // Only warn once per address
      console.warn(`   ⚠️  No API key configured, using fallback for: ${address}`);
    }
    return null;
  }
  
  try {
    // Format address for geocoding
    const fullAddress = `${address}, ${city}, Colombia`;
    const encodedAddress = encodeURIComponent(fullAddress);
    
    // Build API URL with location bias for Bogotá
    const url = `https://maps.googleapis.com/maps/api/geocode/json?address=${encodedAddress}&region=co&bounds=4.4,74.3|4.9,73.8&key=${GEOCODING_CONFIG.apiKey}`;
    
    // Make request
    const response = await fetch(url);
    const data = await response.json();
    
    // Check for errors
    if (data.status === "OVER_QUERY_LIMIT") {
      console.warn(`   ⏸️  Rate limit hit, waiting...`);
      await sleep(GEOCODING_CONFIG.retryDelayMs * 2);
      if (attempt < GEOCODING_CONFIG.maxRetries) {
        return await geocodeAddress(address, city, attempt + 1);
      }
      return null;
    }
    
    if (data.status === "ZERO_RESULTS") {
      console.warn(`   ⚠️  No results for: ${address}`);
      return null;
    }
    
    if (data.status !== "OK" || !data.results || data.results.length === 0) {
      console.warn(`   ⚠️  Geocoding failed for: ${address} (${data.status})`);
      return null;
    }
    
    // Extract coordinates
    const location = data.results[0].geometry.location;
    const result = {
      lat: location.lat,
      lon: location.lng,
      formattedAddress: data.results[0].formatted_address,
      placeId: data.results[0].place_id,
      locationType: data.results[0].geometry.location_type,
    };
    
    // Cache the result
    geocodingCache[cacheKey] = result;
    
    return result;
    
  } catch (error) {
    console.error(`   ❌ Error geocoding ${address}:`, error.message);
    
    // Retry on network errors
    if (attempt < GEOCODING_CONFIG.maxRetries) {
      await sleep(GEOCODING_CONFIG.retryDelayMs);
      return await geocodeAddress(address, city, attempt + 1);
    }
    
    return null;
  }
}

/**
 * Geocode multiple addresses with rate limiting
 */
async function geocodeAddresses(addresses, progressCallback = null) {
  console.log(`\n🗺️  Geocoding ${addresses.length} addresses...`);
  loadCache();
  
  const results = [];
  let geocoded = 0;
  let fromCache = 0;
  let failed = 0;
  
  for (let i = 0; i < addresses.length; i++) {
    const { address, city } = addresses[i];
    const cacheKey = getCacheKey(address, city);
    
    let result;
    if (geocodingCache[cacheKey]) {
      result = geocodingCache[cacheKey];
      fromCache++;
    } else {
      result = await geocodeAddress(address, city);
      if (result) {
        geocoded++;
        // Rate limiting
        if (i < addresses.length - 1) {
          await sleep(GEOCODING_CONFIG.requestDelayMs);
        }
      } else {
        failed++;
      }
    }
    
    results.push({
      address,
      city,
      coordinates: result,
    });
    
    // Progress callback
    if (progressCallback) {
      progressCallback(i + 1, addresses.length, geocoded, fromCache, failed);
    }
    
    // Save cache periodically (every 10 addresses)
    if (i > 0 && i % 10 === 0) {
      saveCache();
    }
  }
  
  // Final save
  saveCache();
  
  console.log(`\n   ✅ Geocoding complete:`);
  console.log(`      - New geocoded: ${geocoded}`);
  console.log(`      - From cache: ${fromCache}`);
  console.log(`      - Failed: ${failed}`);
  
  return results;
}

/**
 * Get coordinates with fallback to localidad-based estimation
 */
function getCoordinatesWithFallback(geocodedResult, localidad, localidadCoordinates) {
  // If geocoding succeeded, use precise coordinates
  if (geocodedResult && geocodedResult.coordinates) {
    return {
      _latitude: geocodedResult.coordinates.lat,
      _longitude: geocodedResult.coordinates.lon,
     
    };
  }
  
  // Fallback to localidad-based coordinates
  let coords = localidadCoordinates[localidad];
  
  // Try case-insensitive match
  if (!coords) {
    const key = Object.keys(localidadCoordinates).find(
      k => k.toLowerCase() === localidad.toLowerCase()
    );
    coords = key ? localidadCoordinates[key] : null;
  }
  
  // Ultimate fallback to Bogotá center
  if (!coords) {
    coords = GEOCODING_CONFIG.defaultLocation;
  }
  
  // Add small random variance
  const variance = 0.015; // ~1.5km
  const latOffset = (Math.random() - 0.5) * variance;
  const lonOffset = (Math.random() - 0.5) * variance;
  
  return {
    _latitude: coords.lat + latOffset,
    _longitude: coords.lon + lonOffset,
    source: "localidad",
    accuracy: "APPROXIMATE",
  };
}

// ===================== EXPORTS =====================
export {
  GEOCODING_CONFIG,
  geocodeAddress,
  geocodeAddresses,
  getCoordinatesWithFallback,
  loadCache,
  saveCache,
};
