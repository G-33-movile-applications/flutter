// Show pharmacy distribution by district
import { readFileSync } from "fs";

const data = JSON.parse(readFileSync("mock_data.json", "utf8"));

const districts = {};
Object.values(data.puntosFisicos).forEach(p => {
  districts[p.localidad] = (districts[p.localidad] || 0) + 1;
});

console.log('\n📊 PHARMACY DISTRIBUTION BY DISTRICT\n');
console.log('District                Count');
console.log('───────────────────────  ─────');

Object.entries(districts)
  .sort((a,b) => b[1]-a[1])
  .forEach(([district, count]) => {
    console.log(`${district.padEnd(23)} ${count}`);
  });

console.log('\n✅ Total:', Object.values(data.puntosFisicos).length, 'pharmacies');
console.log('✅ Districts:', Object.keys(districts).length);
console.log('✅ Average per district:', (Object.values(data.puntosFisicos).length / Object.keys(districts).length).toFixed(1));
