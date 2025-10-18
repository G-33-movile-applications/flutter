// test_geocoding.js
// Quick test to verify Google Maps Geocoding API is working

import { geocodeAddress, GEOCODING_CONFIG } from "./geocoding_service.js";
import dotenv from "dotenv";
dotenv.config();

console.log("\n🔍 Environment Configuration Check\n");

const apiKey = process.env.GOOGLE_MAPS_API_KEY;

if (!apiKey) {
  console.log("❌ GOOGLE_MAPS_API_KEY not found");
  console.log("\n📝 To fix this:");
  console.log("   1. Copy .env.example to .env");
  console.log("   2. Add your Google Maps API key to .env");
  console.log("   3. Get API key from: https://console.cloud.google.com/\n");
} else if (apiKey === "your_api_key_here" || apiKey === "your_actual_api_key_here") {
  console.log("⚠️  Default API key detected - please update .env with your real key\n");
} else {
  console.log("✅ GOOGLE_MAPS_API_KEY configured");
  console.log(`   Key: ${apiKey.substring(0, 10)}...${apiKey.substring(apiKey.length - 4)}`);
  console.log("\n✨ Ready to geocode!\n");
}
async function testGeocodingAPI() {
  console.log("🧪 Testing Google Maps Geocoding API...\n");
  
  // Check if API is configured
  if (!GEOCODING_CONFIG.enabled) {
    console.log("⚠️  Geocoding is DISABLED");
    console.log("   Set enabled: true in geocoding_service.js");
    console.log("   See GEOCODING_SETUP.md for instructions\n");
    return;
  }
  console.log(`GEOCODING_CONFIG.apiKey: ${GEOCODING_CONFIG.apiKey}`);
  if (GEOCODING_CONFIG.apiKey === apiKey && GEOCODING_CONFIG.apiKey) {
    console.log("⚠️  API key not configured");
    console.log("   Replace YOUR_API_KEY_HERE in geocoding_service.js");
    console.log("   See GEOCODING_SETUP.md for instructions\n");
    return;
  }
  
  console.log("✅ API Key configured");
  console.log(`✅ Enabled: ${GEOCODING_CONFIG.enabled}`);
  console.log(`✅ Rate limit: ${1000 / GEOCODING_CONFIG.delayMs} req/sec\n`);
  
  // Test addresses from CSV
  const testAddresses = [
    "KR 32 55 01 SUR",
    "CL 72 05 32",
    "AV CARACAS 25 40",
    "CL 53 127 35",
    "DG 40 A SUR 45 B 55"
  ];
  
  console.log("🗺️  Testing sample pharmacy addresses:\n");
  
  for (const address of testAddresses) {
    console.log(`📍 Testing: "${address}, Bogotá"`);
    
    try {
      const coords = await geocodeAddress(address, "Bogotá");
      
      if (coords) {
        console.log(`   ✅ Geocoded: ${coords._latitude.toFixed(6)}, ${coords._longitude.toFixed(6)}`);
        
        // Validate coordinates are in Bogotá area
        const inBogota = 
          coords._latitude >= 4.0 && coords._latitude <= 5.0 &&
          coords._longitude >= -74.5 && coords._longitude <= -73.5;
        
        if (inBogota) {
          console.log("   ✅ Coordinates are in Bogotá area\n");
        } else {
          console.log("   ⚠️  Coordinates seem outside Bogotá\n");
        }
      } else {
        console.log("   ❌ Failed to geocode (returned null)\n");
      }
    } catch (error) {
      console.log(`   ❌ Error: ${error.message}\n`);
    }
    
    // Wait between requests
    await new Promise(resolve => setTimeout(resolve, GEOCODING_CONFIG.delayMs));
  }
  
  console.log("✨ Test complete!");
  console.log("\n💡 Next steps:");
  console.log("   1. Run: npm run generate");
  console.log("   2. Check: geocoding_cache.json (should have cached results)");
  console.log("   3. Verify: node verify_data.js");
}

// Run test
testGeocodingAPI().catch(error => {
  console.error("❌ Test failed:", error);
  process.exit(1);
});
