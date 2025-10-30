// check_encoding.js
// Checks for encoding issues in generated data

import { readFileSync } from "fs";

console.log("\n🔍 Checking for encoding issues in mock_data.json...\n");

try {
  const data = JSON.parse(readFileSync("mock_data.json", "utf8"));
  
  // Pattern to detect encoding issues
  const badEncodingPattern = /[Ã][\u0080-\u00FF]|�|Â(?!\s)/g;
  const issues = [];
  
  // Check medications
  console.log("📊 Checking medicamentosGlobales...");
  for (const [id, med] of Object.entries(data.medicamentosGlobales)) {
    if (badEncodingPattern.test(med.nombre)) {
      issues.push({ type: 'medication', id, field: 'nombre', value: med.nombre });
    }
    if (badEncodingPattern.test(med.descripcion)) {
      issues.push({ type: 'medication', id, field: 'descripcion', value: med.descripcion });
    }
  }
  
  // Check pharmacies
  console.log("🏪 Checking puntosFisicos...");
  for (const [id, punto] of Object.entries(data.puntosFisicos)) {
    if (badEncodingPattern.test(punto.nombre)) {
      issues.push({ type: 'pharmacy', id, field: 'nombre', value: punto.nombre });
    }
    if (badEncodingPattern.test(punto.direccion)) {
      issues.push({ type: 'pharmacy', id, field: 'direccion', value: punto.direccion });
    }
    if (punto.localidad && badEncodingPattern.test(punto.localidad)) {
      issues.push({ type: 'pharmacy', id, field: 'localidad', value: punto.localidad });
    }
  }
  
  // Report results
  if (issues.length === 0) {
    console.log("\n✅ No encoding issues found!");
    console.log("\n📝 Sample pharmacy names:");
    Object.values(data.puntosFisicos).slice(0, 5).forEach(p => {
      console.log(`   - ${p.nombre}`);
      console.log(`     ${p.direccion}`);
    });
  } else {
    console.log(`\n⚠️  Found ${issues.length} encoding issues:\n`);
    issues.slice(0, 10).forEach(issue => {
      console.log(`   ${issue.type} [${issue.id}] - ${issue.field}:`);
      console.log(`      "${issue.value}"`);
    });
    
    if (issues.length > 10) {
      console.log(`\n   ... and ${issues.length - 10} more issues`);
    }
  }
  
  // Show Spanish character examples
  console.log("\n🔤 Spanish characters in data:");
  const spanishChars = ['á', 'é', 'í', 'ó', 'ú', 'ñ', 'Á', 'É', 'Í', 'Ó', 'Ú', 'Ñ'];
  const foundChars = new Set();
  
  const allText = JSON.stringify(data);
  spanishChars.forEach(char => {
    if (allText.includes(char)) {
      foundChars.add(char);
    }
  });
  
  if (foundChars.size > 0) {
    console.log(`   ✅ Found: ${Array.from(foundChars).join(', ')}`);
  } else {
    console.log(`   ⚠️  No Spanish accented characters found`);
  }
  
  console.log("\n");
  
} catch (error) {
  console.error("❌ Error:", error.message);
}
