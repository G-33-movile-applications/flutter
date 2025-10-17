// Import required modules
const admin = require("firebase-admin");
const fs = require("fs");

// ✅ Use your downloaded service account key
const serviceAccount = require("./mymeds-application-f99dd-firebase-adminsdk-fbsvc-2f530ed294.json");

// Initialize Firebase Admin SDK
admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

// ✅ Replace with your JSON file 
const data = JSON.parse(fs.readFileSync("mock_firestore_data_new.json", "utf8"));

// Helper: Recursively convert date strings to Firestore Timestamps
function convertDates(obj) {
    if (Array.isArray(obj)) {
        return obj.map(convertDates);
    } else if (obj && typeof obj === "object") {
        const newObj = {};
        for (const [key, value] of Object.entries(obj)) {
            if (typeof value === "string" && /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/.test(value)) {
                newObj[key] = admin.firestore.Timestamp.fromDate(new Date(value));
            } else {
                newObj[key] = convertDates(value);
            }
        }
        return newObj;
    } else {
        return obj;
    }
}

// Main seeding function
async function seed() {
    for (const [collectionName, docs] of Object.entries(data)) {
        for (const [docId, docData] of Object.entries(docs)) {
            const convertedData = convertDates(docData);
            await db.collection(collectionName).doc(docId).set(convertedData);
            console.log(`✅ Inserted ${docId} into ${collectionName}`);
        }
    }
    console.log("🌱 Seeding completed!");
}

// Run seeding
seed().catch((err) => console.error("❌ Error seeding Firestore:", err));
