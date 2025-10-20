// seed_firestore.js
// Seeds Firestore with generated mock data
// Handles nested subcollections and avoids duplicates

import admin from "firebase-admin";
import { readFileSync } from "fs";

// ===================== CONFIGURATION =====================
// Load service account key
const serviceAccount = JSON.parse(
  readFileSync("mymeds-application-f99dd-firebase-adminsdk-fbsvc-2e9bfb7fb0.json", "utf8")
);

// Initialize Firebase Admin SDK
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

// Configuration options
const CONFIG = {
  checkExisting: true, // Skip existing documents
  batchSize: 500, // Firestore batch limit
  dryRun: false, // Set to true to preview without writing
};

// ===================== HELPER FUNCTIONS =====================

/**
 * Recursively convert date strings to Firestore Timestamps
 */
function convertDates(obj) {
  if (Array.isArray(obj)) {
    return obj.map(convertDates);
  } else if (obj && typeof obj === "object") {
    const newObj = {};
    for (const [key, value] of Object.entries(obj)) {
      // Convert ISO date strings to Firestore Timestamps
      if (typeof value === "string" && /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/.test(value)) {
        newObj[key] = admin.firestore.Timestamp.fromDate(new Date(value));
      }
      // Convert GeoPoint format
      else if (key === "ubicacion" && value._latitude !== undefined && value._longitude !== undefined) {
        newObj[key] = new admin.firestore.GeoPoint(value._latitude, value._longitude);
      }
      else {
        newObj[key] = convertDates(value);
      }
    }
    return newObj;
  }
  return obj;
}

/**
 * Check if document exists
 */
async function documentExists(collectionPath, docId) {
  const docRef = db.collection(collectionPath).doc(docId);
  const doc = await docRef.get();
  return doc.exists;
}

/**
 * Seed a top-level collection
 */
async function seedCollection(collectionName, data) {
  console.log(`\n📊 Seeding ${collectionName}...`);
  let created = 0;
  let skipped = 0;
  let batch = db.batch();
  let batchCount = 0;

  for (const [docId, docData] of Object.entries(data)) {
    // Check if document already exists
    if (CONFIG.checkExisting) {
      const exists = await documentExists(collectionName, docId);
      if (exists) {
        skipped++;
        continue;
      }
    }

    // Convert dates and GeoPoints
    const convertedData = convertDates(docData);

    if (CONFIG.dryRun) {
      console.log(`   [DRY RUN] Would create: ${collectionName}/${docId}`);
      created++;
    } else {
      const docRef = db.collection(collectionName).doc(docId);
      batch.set(docRef, convertedData);
      batchCount++;
      created++;

      // Commit batch if limit reached
      if (batchCount >= CONFIG.batchSize) {
        await batch.commit();
        console.log(`   💾 Committed batch of ${batchCount} documents`);
        batch = db.batch();
        batchCount = 0;
      }
    }
  }

  // Commit remaining documents
  if (batchCount > 0 && !CONFIG.dryRun) {
    await batch.commit();
    console.log(`   💾 Committed final batch of ${batchCount} documents`);
  }

  console.log(`   ✅ Created: ${created} | Skipped: ${skipped}`);
  return { created, skipped };
}

/**
 * Seed subcollection (e.g., inventarios under puntosFisicos)
 */
async function seedSubcollection(parentCollection, subcollectionName, data) {
  console.log(`\n📦 Seeding ${parentCollection}/{id}/${subcollectionName}...`);
  let created = 0;
  let skipped = 0;
  let batch = db.batch();
  let batchCount = 0;

  for (const [parentDocId, subDocs] of Object.entries(data)) {
    for (const [subDocId, subDocData] of Object.entries(subDocs)) {
      // Check if subdocument already exists
      if (CONFIG.checkExisting) {
        const subDocRef = db
          .collection(parentCollection)
          .doc(parentDocId)
          .collection(subcollectionName)
          .doc(subDocId);
        const subDoc = await subDocRef.get();
        if (subDoc.exists) {
          skipped++;
          continue;
        }
      }

      // Convert dates
      const convertedData = convertDates(subDocData);

      if (CONFIG.dryRun) {
        console.log(`   [DRY RUN] Would create: ${parentCollection}/${parentDocId}/${subcollectionName}/${subDocId}`);
        created++;
      } else {
        const subDocRef = db
          .collection(parentCollection)
          .doc(parentDocId)
          .collection(subcollectionName)
          .doc(subDocId);
        batch.set(subDocRef, convertedData);
        batchCount++;
        created++;

        // Commit batch if limit reached
        if (batchCount >= CONFIG.batchSize) {
          await batch.commit();
          console.log(`   💾 Committed batch of ${batchCount} documents`);
          batch = db.batch();
          batchCount = 0;
        }
      }
    }
  }

  // Commit remaining documents
  if (batchCount > 0 && !CONFIG.dryRun) {
    await batch.commit();
    console.log(`   💾 Committed final batch of ${batchCount} documents`);
  }

  console.log(`   ✅ Created: ${created} | Skipped: ${skipped}`);
  return { created, skipped };
}

/**
 * Seed nested subcollection (e.g., medicamentos under prescripciones under usuarios)
 */
async function seedNestedSubcollection(
  parentCollection,
  midCollection,
  nestedCollection,
  data
) {
  console.log(`\n💊 Seeding ${parentCollection}/{id}/${midCollection}/{id}/${nestedCollection}...`);
  let created = 0;
  let skipped = 0;
  let batch = db.batch();
  let batchCount = 0;

  for (const [parentDocId, midDocs] of Object.entries(data)) {
    for (const [midDocId, nestedDocs] of Object.entries(midDocs)) {
      for (const [nestedDocId, nestedDocData] of Object.entries(nestedDocs)) {
        // Check if nested document already exists
        if (CONFIG.checkExisting) {
          const nestedDocRef = db
            .collection(parentCollection)
            .doc(parentDocId)
            .collection(midCollection)
            .doc(midDocId)
            .collection(nestedCollection)
            .doc(nestedDocId);
          const nestedDoc = await nestedDocRef.get();
          if (nestedDoc.exists) {
            skipped++;
            continue;
          }
        }

        // Convert dates
        const convertedData = convertDates(nestedDocData);

        if (CONFIG.dryRun) {
          console.log(
            `   [DRY RUN] Would create: ${parentCollection}/${parentDocId}/${midCollection}/${midDocId}/${nestedCollection}/${nestedDocId}`
          );
          created++;
        } else {
          const nestedDocRef = db
            .collection(parentCollection)
            .doc(parentDocId)
            .collection(midCollection)
            .doc(midDocId)
            .collection(nestedCollection)
            .doc(nestedDocId);
          batch.set(nestedDocRef, convertedData);
          batchCount++;
          created++;

          // Commit batch if limit reached
          if (batchCount >= CONFIG.batchSize) {
            await batch.commit();
            console.log(`   💾 Committed batch of ${batchCount} documents`);
            batch = db.batch();
            batchCount = 0;
          }
        }
      }
    }
  }

  // Commit remaining documents
  if (batchCount > 0 && !CONFIG.dryRun) {
    await batch.commit();
    console.log(`   💾 Committed final batch of ${batchCount} documents`);
  }

  console.log(`   ✅ Created: ${created} | Skipped: ${skipped}`);
  return { created, skipped };
}

// ===================== MAIN SEEDING FUNCTION =====================
async function seedFirestore() {
  console.log("🌱 Starting Firestore seeding...");
  console.log(`⚙️  Configuration:`);
  console.log(`   - Check existing: ${CONFIG.checkExisting}`);
  console.log(`   - Batch size: ${CONFIG.batchSize}`);
  console.log(`   - Dry run: ${CONFIG.dryRun ? "YES (no writes)" : "NO (will write)"}`);

  try {
    // Load mock data
    console.log("\n📄 Loading mock_data.json...");
    const data = JSON.parse(readFileSync("mock_data.json", "utf8"));
    console.log("   ✅ Data loaded successfully");

    const stats = {
      created: 0,
      skipped: 0,
    };

    // 1. Seed top-level collections
    console.log("\n" + "=".repeat(50));
    console.log("SEEDING TOP-LEVEL COLLECTIONS");
    console.log("=".repeat(50));

    let result = await seedCollection("medicamentosGlobales", data.medicamentosGlobales);
    stats.created += result.created;
    stats.skipped += result.skipped;

    result = await seedCollection("puntosFisicos", data.puntosFisicos);
    stats.created += result.created;
    stats.skipped += result.skipped;

    // Only seed usuarios if they are new (not fetched from existing database)
    if (Object.keys(data.usuarios).length > 0) {
      // Check if usuarios have createdAt as string (new) or Timestamp (existing)
      const firstUser = Object.values(data.usuarios)[0];
      const isNewUser = typeof firstUser.createdAt === 'string';
      
      if (isNewUser) {
        console.log("\n📝 Note: Seeding new usuarios...");
        result = await seedCollection("usuarios", data.usuarios);
        stats.created += result.created;
        stats.skipped += result.skipped;
      } else {
        console.log("\n⏭️  Skipping usuarios seeding (using existing users from database)");
      }
    }

    // 2. Seed subcollections
    console.log("\n" + "=".repeat(50));
    console.log("SEEDING SUBCOLLECTIONS");
    console.log("=".repeat(50));

    // Inventarios under puntosFisicos
    result = await seedSubcollection("puntosFisicos", "inventario", data.inventarios);
    stats.created += result.created;
    stats.skipped += result.skipped;

    // Prescripciones under usuarios
    result = await seedSubcollection("usuarios", "prescripciones", data.prescripciones);
    stats.created += result.created;
    stats.skipped += result.skipped;

    // Pedidos under usuarios
    result = await seedSubcollection("usuarios", "pedidos", data.pedidos);
    stats.created += result.created;
    stats.skipped += result.skipped;

    // MedicamentosUsuario under usuarios
    result = await seedSubcollection("usuarios", "medicamentosUsuario", data.medicamentosUsuario);
    stats.created += result.created;
    stats.skipped += result.skipped;

    // 3. Seed nested subcollections
    console.log("\n" + "=".repeat(50));
    console.log("SEEDING NESTED SUBCOLLECTIONS");
    console.log("=".repeat(50));

    // Medicamentos under prescripciones under usuarios
    result = await seedNestedSubcollection(
      "usuarios",
      "prescripciones",
      "medicamentos",
      data.medicamentosPrescripcion
    );
    stats.created += result.created;
    stats.skipped += result.skipped;

    // Medicamentos under pedidos under usuarios
    result = await seedNestedSubcollection(
      "usuarios",
      "pedidos",
      "medicamentos",
      data.medicamentosPedido
    );
    stats.created += result.created;
    stats.skipped += result.skipped;

    // Summary
    console.log("\n" + "=".repeat(50));
    console.log("SEEDING COMPLETED");
    console.log("=".repeat(50));
    console.log(`✅ Total documents created: ${stats.created}`);
    console.log(`⏭️  Total documents skipped: ${stats.skipped}`);
    
    if (CONFIG.dryRun) {
      console.log("\n⚠️  DRY RUN MODE - No data was written to Firestore");
    } else {
      console.log("\n🎉 All data successfully seeded to Firestore!");
    }

  } catch (error) {
    console.error("\n❌ Error seeding Firestore:", error);
    throw error;
  }
}

// ===================== RUN SEEDING =====================
seedFirestore()
  .then(() => {
    console.log("\n✅ Script completed successfully");
    process.exit(0);
  })
  .catch((error) => {
    console.error("\n❌ Script failed:", error);
    process.exit(1);
  });
