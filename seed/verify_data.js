// Quick verification script
import { readFileSync } from "fs";

const data = JSON.parse(readFileSync("mock_data.json", "utf8"));

console.log("🏪 SAMPLE PHARMACIES (Real data from CSV):\n");
const pharmacies = Object.values(data.puntosFisicos).slice(0, 10);
pharmacies.forEach((p, i) => {
  console.log(`${i+1}. ${p.nombre}`);
  console.log(`   📍 ${p.direccion}`);
  console.log(`   🏘️  ${p.localidad || 'N/A'}`);
  console.log(`   🗺️  Lat: ${p.ubicacion._latitude.toFixed(4)}, Lon: ${p.ubicacion._longitude.toFixed(4)}`);
  console.log(`   📞 ${p.telefono}`);
  console.log(`   ⏰ ${p.horario}\n`);
});

console.log("\n👥 EXISTING USERS:\n");
const users = Object.values(data.usuarios).slice(0, 5);
users.forEach((u, i) => {
  console.log(`${i+1}. ${u.nombre}`);
  console.log(`   📧 ${u.email}`);
  console.log(`   📍 ${u.direccion}, ${u.city}\n`);
});

console.log("\n💊 SAMPLE MEDICATIONS:\n");
const meds = Object.values(data.medicamentosGlobales).slice(0, 5);
meds.forEach((m, i) => {
  console.log(`${i+1}. ${m.nombre}`);
  console.log(`   🏭 ${m.laboratorio}`);
  console.log(`   💊 ${m.presentacion}\n`);
});
