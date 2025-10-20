// preview_changes.js
// Shows what will be generated without actually writing to Firestore

import { readFileSync } from "fs";

console.log("\n🔍 Preview of Generated Data Structure\n");
console.log("=".repeat(60));

try {
  const data = JSON.parse(readFileSync("mock_data.json", "utf8"));
  
  // Medications
  const medIds = Object.keys(data.medicamentosGlobales);
  console.log("\n📊 MEDICATIONS (medicamentosGlobales)");
  console.log(`   Total: ${medIds.length}`);
  if (medIds.length > 0) {
    console.log(`   IDs: ${medIds[0]} to ${medIds[medIds.length - 1]}`);
    console.log(`   Sample names:`);
    medIds.slice(0, 3).forEach(id => {
      console.log(`      - ${id}: ${data.medicamentosGlobales[id].nombre}`);
    });
  }
  
  // Pharmacies
  const puntoIds = Object.keys(data.puntosFisicos);
  console.log("\n🏪 PHARMACIES (puntosFisicos)");
  console.log(`   Total: ${puntoIds.length}`);
  if (puntoIds.length > 0) {
    console.log(`   Sample addresses:`);
    puntoIds.slice(0, 3).forEach(id => {
      const punto = data.puntosFisicos[id];
      console.log(`      - ${punto.nombre}`);
      console.log(`        ${punto.direccion}`);
    });
  }
  
  // Users
  const userIds = Object.keys(data.usuarios);
  console.log("\n👥 USERS (usuarios)");
  if (userIds.length === 0) {
    console.log(`   ✅ Empty (will NOT overwrite existing users)`);
    console.log(`   💡 This is correct - existing users are preserved`);
  } else {
    console.log(`   Total: ${userIds.length}`);
  }
  
  // Prescriptions
  console.log("\n💊 PRESCRIPTIONS (usuarios/{userId}/prescripciones)");
  const prescUserIds = Object.keys(data.prescripciones);
  let totalPresc = 0;
  prescUserIds.forEach(userId => {
    totalPresc += Object.keys(data.prescripciones[userId]).length;
  });
  console.log(`   Users with prescriptions: ${prescUserIds.length}`);
  console.log(`   Total prescriptions: ${totalPresc}`);
  if (prescUserIds.length > 0) {
    const firstUserId = prescUserIds[0];
    const firstUserPresc = Object.keys(data.prescripciones[firstUserId]);
    console.log(`   Sample for user ${firstUserId.substring(0, 10)}...:`);
    console.log(`      - Prescriptions: ${firstUserPresc.length}`);
    
    // Show nested medications
    if (data.medicamentosPrescripcion[firstUserId]) {
      const prescId = firstUserPresc[0];
      if (data.medicamentosPrescripcion[firstUserId][prescId]) {
        const meds = Object.keys(data.medicamentosPrescripcion[firstUserId][prescId]);
        console.log(`      - Medications in first prescription: ${meds.length}`);
      }
    }
  }
  
  // Orders
  console.log("\n🛒 ORDERS (usuarios/{userId}/pedidos)");
  const pedidoUserIds = Object.keys(data.pedidos);
  let totalPedidos = 0;
  pedidoUserIds.forEach(userId => {
    totalPedidos += Object.keys(data.pedidos[userId]).length;
  });
  console.log(`   Users with orders: ${pedidoUserIds.length}`);
  console.log(`   Total orders: ${totalPedidos}`);
  
  // User medications
  console.log("\n💊 USER MEDICATIONS (usuarios/{userId}/medicamentosUsuario)");
  const medUserIds = Object.keys(data.medicamentosUsuario);
  let totalMedUser = 0;
  medUserIds.forEach(userId => {
    totalMedUser += Object.keys(data.medicamentosUsuario[userId]).length;
  });
  console.log(`   Users with medications: ${medUserIds.length}`);
  console.log(`   Total user medications: ${totalMedUser}`);
  
  // Summary
  console.log("\n" + "=".repeat(60));
  console.log("📋 WHAT WILL HAPPEN WHEN YOU RUN 'npm run seed':");
  console.log("=".repeat(60));
  console.log(`\n✅ WILL BE ADDED:`);
  console.log(`   - ${medIds.length} medications (with incremental IDs)`);
  console.log(`   - ${puntoIds.length} pharmacies (with formatted addresses)`);
  console.log(`   - ${totalPresc} prescriptions (to existing users)`);
  console.log(`   - ${totalPedidos} orders (to existing users)`);
  console.log(`   - ${totalMedUser} user medications (to existing users)`);
  
  console.log(`\n✅ WILL NOT BE TOUCHED:`);
  console.log(`   - Existing users (name, email, phone, etc.)`);
  console.log(`   - Existing medications (with lower IDs)`);
  console.log(`   - Any existing user data`);
  
  console.log(`\n⚠️  NOTE:`);
  console.log(`   - If you run this multiple times, MORE data will be added`);
  console.log(`   - Set checkExisting: true in seed_firestore.js to skip duplicates`);
  console.log(`   - User subcollections will accumulate with each run`);
  
  console.log("\n" + "=".repeat(60));
  console.log("✨ Ready to seed! Run: npm run seed");
  console.log("=".repeat(60) + "\n");
  
} catch (error) {
  console.error("❌ Error reading mock_data.json:", error.message);
  console.log("\n💡 Run 'npm run generate' first to create the data file.\n");
}
