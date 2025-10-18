// verify_medication_consistency.js
// Verifies that medications in prescriptions match medications in medicamentosUsuario

import { readFileSync } from "fs";

console.log("\n🔍 Verifying medication consistency...\n");
console.log("=".repeat(60));

try {
  const data = JSON.parse(readFileSync("mock_data.json", "utf8"));
  
  let totalUsers = 0;
  let consistentUsers = 0;
  let inconsistentUsers = 0;
  const issues = [];
  
  // Check each user
  for (const userId in data.prescripciones) {
    totalUsers++;
    
    // Collect all medications from user's prescriptions
    const prescriptionMeds = new Set();
    if (data.medicamentosPrescripcion[userId]) {
      for (const presId in data.medicamentosPrescripcion[userId]) {
        for (const medId in data.medicamentosPrescripcion[userId][presId]) {
          prescriptionMeds.add(medId);
        }
      }
    }
    
    // Collect all medications from user's medicamentosUsuario
    const userMeds = new Set();
    if (data.medicamentosUsuario[userId]) {
      for (const medId in data.medicamentosUsuario[userId]) {
        const medData = data.medicamentosUsuario[userId][medId];
        // Only count medications that have a prescription ID
        if (medData.prescripcionId) {
          userMeds.add(medId);
        }
      }
    }
    
    // Check consistency
    const missingInUserMeds = [...prescriptionMeds].filter(id => !userMeds.has(id));
    
    if (missingInUserMeds.length > 0) {
      inconsistentUsers++;
      issues.push({
        userId,
        prescriptionMeds: prescriptionMeds.size,
        userMeds: userMeds.size,
        missing: missingInUserMeds,
      });
    } else {
      consistentUsers++;
    }
  }
  
  // Report results
  console.log(`\n📊 VERIFICATION RESULTS:\n`);
  console.log(`   Total users checked: ${totalUsers}`);
  console.log(`   ✅ Consistent users: ${consistentUsers}`);
  console.log(`   ❌ Inconsistent users: ${inconsistentUsers}`);
  
  if (inconsistentUsers === 0) {
    console.log(`\n✅ PERFECT! All medications are consistent!`);
    console.log(`   All medications in prescriptions are also in medicamentosUsuario.\n`);
  } else {
    console.log(`\n⚠️  ISSUES FOUND:\n`);
    issues.forEach((issue, idx) => {
      console.log(`   ${idx + 1}. User ${issue.userId.substring(0, 10)}...`);
      console.log(`      - Prescription meds: ${issue.prescriptionMeds}`);
      console.log(`      - User meds (with prescription): ${issue.userMeds}`);
      console.log(`      - Missing in medicamentosUsuario: ${issue.missing.length}`);
      issue.missing.slice(0, 3).forEach(medId => {
        const medName = data.medicamentosGlobales[medId]?.nombre || 'Unknown';
        console.log(`        • ${medId}: ${medName}`);
      });
      if (issue.missing.length > 3) {
        console.log(`        ... and ${issue.missing.length - 3} more`);
      }
      console.log();
    });
  }
  
  // Show sample user detail
  if (totalUsers > 0) {
    const sampleUserId = Object.keys(data.prescripciones)[0];
    console.log("=".repeat(60));
    console.log(`📋 SAMPLE USER DETAIL: ${sampleUserId.substring(0, 15)}...\n`);
    
    // Prescriptions
    const userPresc = data.prescripciones[sampleUserId];
    console.log(`   Prescriptions: ${Object.keys(userPresc).length}`);
    
    for (const [presId, presc] of Object.entries(userPresc)) {
      console.log(`\n   📄 Prescription ${presId.substring(0, 10)}...`);
      console.log(`      Status: ${presc.activa ? 'ACTIVE' : 'Inactive'}`);
      console.log(`      Medications in prescription:`);
      
      if (data.medicamentosPrescripcion[sampleUserId]?.[presId]) {
        for (const [medId, med] of Object.entries(data.medicamentosPrescripcion[sampleUserId][presId])) {
          console.log(`        - ${med.nombre} (${med.dosis})`);
        }
      }
    }
    
    // User medications
    console.log(`\n   💊 User Medications Collection:`);
    if (data.medicamentosUsuario[sampleUserId]) {
      const userMedsList = Object.values(data.medicamentosUsuario[sampleUserId]);
      const withPrescription = userMedsList.filter(m => m.prescripcionId);
      const withoutPrescription = userMedsList.filter(m => !m.prescripcionId);
      
      console.log(`      Total: ${userMedsList.length}`);
      console.log(`      - From prescriptions: ${withPrescription.length}`);
      console.log(`      - Extra (no prescription): ${withoutPrescription.length}`);
      
      console.log(`\n      Medications:`);
      userMedsList.forEach(med => {
        const status = med.activo ? '✅ ACTIVE' : '⏸️  Inactive';
        const prescInfo = med.prescripcionId ? `📄 ${med.prescripcionId.substring(0, 8)}...` : '❌ No prescription';
        console.log(`        ${status} ${med.nombre} - ${prescInfo}`);
      });
    }
  }
  
  console.log("\n" + "=".repeat(60));
  
  if (inconsistentUsers === 0) {
    console.log("✨ All checks passed! Data is consistent.\n");
  } else {
    console.log("⚠️  Please regenerate data to fix consistency issues.\n");
  }
  
} catch (error) {
  console.error("❌ Error:", error.message);
  console.log("\n💡 Run 'npm run generate' first to create the data file.\n");
}
