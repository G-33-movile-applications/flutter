// Analyze localidad coordinate distribution
import { readFileSync } from "fs";

const data = JSON.parse(readFileSync("mock_data.json", "utf8"));

console.log("📊 COORDINATE ANALYSIS BY LOCALIDAD\n");

// Expected centers (from code)
const EXPECTED_CENTERS = {
  "Tunjuelito": { lat: 4.5743, lon: -74.1299 },
  "Engativá": { lat: 4.7007, lon: -74.1140 },
  "Fontibón": { lat: 4.6738, lon: -74.1435 },
  "Usme": { lat: 4.4968, lon: -74.1279 },
  "Rafael Uribe": { lat: 4.5649, lon: -74.1157 },
  "Centro Oriente": { lat: 4.6000, lon: -74.0700 },
  "Sur": { lat: 4.5500, lon: -74.1500 },
  "Vista Hermosa": { lat: 4.5500, lon: -74.1200 },
};

// Group pharmacies by localidad
const byLocalidad = {};
const pharmacies = Object.values(data.puntosFisicos);

pharmacies.forEach(p => {
  const loc = p.localidad || 'Unknown';
  if (!byLocalidad[loc]) byLocalidad[loc] = [];
  byLocalidad[loc].push(p);
});

// Analyze each localidad
Object.entries(byLocalidad).sort((a, b) => b[1].length - a[1].length).forEach(([loc, list]) => {
  const avgLat = list.reduce((sum, p) => sum + p.ubicacion._latitude, 0) / list.length;
  const avgLon = list.reduce((sum, p) => sum + p.ubicacion._longitude, 0) / list.length;
  
  console.log(`${loc}:`);
  console.log(`  Count: ${list.length} pharmacies`);
  console.log(`  Average Coordinates: ${avgLat.toFixed(4)}, ${avgLon.toFixed(4)}`);
  
  if (EXPECTED_CENTERS[loc]) {
    const expected = EXPECTED_CENTERS[loc];
    const latDiff = Math.abs(avgLat - expected.lat).toFixed(4);
    const lonDiff = Math.abs(avgLon - expected.lon).toFixed(4);
    console.log(`  Expected Center: ${expected.lat.toFixed(4)}, ${expected.lon.toFixed(4)}`);
    console.log(`  Deviation: ±${latDiff} lat, ±${lonDiff} lon`);
    
    // Check if within acceptable range (~1.5km = 0.015 degrees)
    const withinRange = latDiff < 0.015 && lonDiff < 0.015;
    console.log(`  Status: ${withinRange ? '✅ Accurate' : '⚠️  Check variance'}`);
  }
  
  console.log();
});

console.log("📍 COORDINATE RANGES:");
console.log(`  Latitude: ${Math.min(...pharmacies.map(p => p.ubicacion._latitude)).toFixed(4)} to ${Math.max(...pharmacies.map(p => p.ubicacion._latitude)).toFixed(4)}`);
console.log(`  Longitude: ${Math.min(...pharmacies.map(p => p.ubicacion._longitude)).toFixed(4)} to ${Math.max(...pharmacies.map(p => p.ubicacion._longitude)).toFixed(4)}`);

// Show sample from each unique localidad
console.log("\n🏘️  SAMPLE PHARMACY PER LOCALIDAD:");
Object.entries(byLocalidad).slice(0, 5).forEach(([loc, list]) => {
  const sample = list[0];
  console.log(`\n${loc}:`);
  console.log(`  ${sample.nombre}`);
  console.log(`  📍 ${sample.direccion}`);
  console.log(`  🗺️  ${sample.ubicacion._latitude.toFixed(4)}, ${sample.ubicacion._longitude.toFixed(4)}`);
});
