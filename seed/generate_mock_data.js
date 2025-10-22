// generate_mock_data.js
// Generates realistic mock data for MyMeds Firestore collections
// Compatible with Flutter models and current schema

import { writeFileSync, readFileSync } from "fs";
import { faker } from "@faker-js/faker";
import admin from "firebase-admin";
import {
  GEOCODING_CONFIG,
  geocodeAddresses,
  getCoordinatesWithFallback,
} from "./geocoding_service.js";

// ===================== CONFIGURATION =====================
const CONFIG = {
  numMedicamentosGlobales: 15,
  numPuntosFisicos: 20, // Will use real pharmacies from CSV
  useExistingUsers: true, // Fetch users from Firestore
  maxUsersToFetch: 20, // Limit number of users to work with
  prescripcionesPorUsuario: { min: 1, max: 4 },
  medicamentosPorPrescripcion: { min: 1, max: 3 },
  pedidosPorUsuario: { min: 1, max: 5 },
  medicamentosUsuarioPorUsuario: { min: 1, max: 5 },
  inventarioPorFarmacia: { min: 4, max: 16 },
  
  // Filter pharmacies by specific localidades (districts)
  // Leave empty [] to use all localidades
  // Example: ["Chapinero", "Usaquén", "Suba"]
  filtrarLocalidades: [], // Set specific areas or leave empty for all
};

// Firebase Admin SDK initialization
let db = null;
const initializeFirebase = () => {
  if (!admin.apps.length) {
    const serviceAccount = JSON.parse(
      readFileSync("mymeds-application-f99dd-firebase-adminsdk-fbsvc-2e9bfb7fb0.json", "utf8")
    );
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
    });
  }
  db = admin.firestore();
};

// Colombian cities and departments
const COLOMBIA_DATA = {
  departments: ["Bogotá D.C."],
  cities: {
    "Cundinamarca": ["Mosquera", "Soacha", "Chía", "Funza", "Zipaquirá"],
    "Bogotá D.C.": ["Bogotá"],
    "Antioquia": ["Medellín", "Bello", "Envigado", "Itagüí"],
    "Valle del Cauca": ["Cali", "Palmira", "Buenaventura"],
  },
  zipCodes: {
    "Bogotá": ["110111", "110121", "110131", "110211"],
    "Mosquera": ["250040", "250041"],
    "Soacha": ["250051", "250052"],
    "Medellín": ["050001", "050010", "050021"],
    "Cali": ["760001", "760010", "760020"],
  }
};

// ===================== CSV PARSING =====================
/**
 * Parse CSV file with pharmacy data from Bogotá
 */
function parsePharmacyCSV() {
  try {
    const csvContent = readFileSync("DROGUERIAS_BOGOTA.csv", "utf8");
    const lines = csvContent.split('\n').slice(1); // Skip header
    const pharmacies = [];

    for (const line of lines) {
      if (!line.trim()) continue;
      
      const parts = line.split(';');
      if (parts.length >= 5) {
        const [razonSocial, direccion, telefono, abierto24h, localidad] = parts;
        
        if (razonSocial && direccion) {
          const cleanLocalidad = localidad ? fixSpanishEncoding(localidad.trim()) : 'Bogotá';
          
          // Filter by localidades if specified in config
          if (CONFIG.filtrarLocalidades.length > 0) {
            const matchesFilter = CONFIG.filtrarLocalidades.some(filter => 
              cleanLocalidad.toLowerCase().includes(filter.toLowerCase()) ||
              filter.toLowerCase().includes(cleanLocalidad.toLowerCase())
            );
            if (!matchesFilter) continue;
          }
          
          pharmacies.push({
            nombre: fixSpanishEncoding(razonSocial.trim()),
            direccion: direccion.trim(),
            telefono: telefono.trim() || `601${faker.number.int({ min: 2000000, max: 9999999 })}`,
            abierto24h: abierto24h.trim() === '1',
            localidad: cleanLocalidad,
          });
        }
      }
    }

    const filterMsg = CONFIG.filtrarLocalidades.length > 0 
      ? ` (filtered by: ${CONFIG.filtrarLocalidades.join(', ')})` 
      : '';
    console.log(`   📄 Parsed ${pharmacies.length} pharmacies from CSV${filterMsg}`);
    return pharmacies;
  } catch (error) {
    console.error("   ⚠️  Error parsing CSV, using fallback data:", error.message);
    return [];
  }
}

/**
 * Get coordinates for a pharmacy based on its localidad
 * Returns coordinates near the district center with slight variance
 */
function getCoordinatesForLocalidad(localidad) {
  // Try to find exact match first
  let coords = LOCALIDAD_COORDINATES[localidad];
  
  // Try case-insensitive match
  if (!coords) {
    const key = Object.keys(LOCALIDAD_COORDINATES).find(
      k => k.toLowerCase() === localidad.toLowerCase()
    );
    coords = key ? LOCALIDAD_COORDINATES[key] : null;
  }
  
  // Fallback to Bogotá center
  if (!coords) {
    coords = BOGOTA_CENTER;
  }
  
  // Add small random variance to avoid exact duplicates
  // Variance is smaller now (~1.5km) to stay within the district
  const latOffset = (Math.random() - 0.5) * COORD_RANGE;
  const lonOffset = (Math.random() - 0.5) * COORD_RANGE;
  
  return {
    _latitude: coords.lat + latOffset,
    _longitude: coords.lon + lonOffset,
  };
}

const PHARMACY_CHAINS = [
  "Farmatodo", "Cruz Verde", "Cafam", "Droguerías La Rebaja",
  "Farmacias del Ahorro", "Locatel", "Farmacias Económicas"
];

const MEDICINE_DATA = {
  principiosActivos: [
    "Paracetamol", "Ibuprofeno", "Amoxicilina", "Losartán", "Metformina",
    "Omeprazol", "Atorvastatina", "Loratadina", "Salbutamol", "Ácido Fólico",
    "Ranitidina", "Diclofenaco", "Cetirizina", "Captopril", "Simvastatina"
  ],
  presentaciones: ["Tableta", "Cápsula", "Jarabe", "Suspensión", "Inhalador", "Crema"],
  laboratorios: [
    "Laboratorios Farmacol", "Tecnoquímicas", "Genfar", "Lafrancol",
    "Procaps", "MK", "La Santé", "Abbott", "Bayer", "Pfizer"
  ]
};

// Bogotá coordinates by localidad (district)
// These are approximate centers for each district in Bogotá
const LOCALIDAD_COORDINATES = {
  "Usaquén": { lat: 4.7050, lon: -74.0306 },
  "Chapinero": { lat: 4.6500, lon: -74.0636 },
  "Santa Fe": { lat: 4.6126, lon: -74.0698 },
  "San Cristóbal": { lat: 4.5697, lon: -74.0849 },
  "Usme": { lat: 4.4968, lon: -74.1279 },
  "Tunjuelito": { lat: 4.5743, lon: -74.1299 },
  "Bosa": { lat: 4.6178, lon: -74.1930 },
  "Kennedy": { lat: 4.6288, lon: -74.1630 },
  "Fontibón": { lat: 4.6738, lon: -74.1435 },
  "Engativá": { lat: 4.7007, lon: -74.1140 },
  "Suba": { lat: 4.7428, lon: -74.0878 },
  "Barrios Unidos": { lat: 4.6608, lon: -74.0789 },
  "Teusaquillo": { lat: 4.6400, lon: -74.0900 },
  "Los Mártires": { lat: 4.6051, lon: -74.0863 },
  "Antonio Nariño": { lat: 4.5881, lon: -74.1054 },
  "Puente Aranda": { lat: 4.6100, lon: -74.1200 },
  "La Candelaria": { lat: 4.5973, lon: -74.0745 },
  "Rafael Uribe": { lat: 4.5649, lon: -74.1157 },
  "Rafael Uribe Uribe": { lat: 4.5649, lon: -74.1157 },
  "Ciudad Bolívar": { lat: 4.5731, lon: -74.1669 },
  "Sumapaz": { lat: 4.2673, lon: -74.2389 },
  // Alternative names in CSV (with encoding issues fixed)
  "Usaquén": { lat: 4.7050, lon: -74.0306 },
  "San Cristóbal": { lat: 4.5697, lon: -74.0849 },
  "Fontibón": { lat: 4.6738, lon: -74.1435 },
  "Engativá": { lat: 4.7007, lon: -74.1140 },
  "Tunjuelito": { lat: 4.5743, lon: -74.1299 },
  "Vista Hermosa": { lat: 4.5500, lon: -74.1200 }, // Part of Ciudad Bolívar
  "Centro Oriente": { lat: 4.6000, lon: -74.0700 }, // Near Santa Fe
  "Sur": { lat: 4.5500, lon: -74.1500 }, // General south area
};

const contraindicaciones= [
  "No usar en caso de alergia al principio activo.",
  "Consultar al médico si está embarazada o en periodo de lactancia.",
  "No combinar con alcohol.",
  "Mantener fuera del alcance de los niños.",
  "No exceder la dosis recomendada.",
];

const BOGOTA_CENTER = { lat: 4.6533, lon: -74.0836 };
const COORD_RANGE = 0.015; // ~1.5km range for localidad variance

// ===================== HELPER FUNCTIONS =====================
const randomId = () => faker.string.alphanumeric(20);
const randomDate = (start, end) => faker.date.between({ from: start, to: end });
const randomCoord = (center, range) => center + (Math.random() - 0.5) * range;
const randomInt = (min, max) => Math.floor(Math.random() * (max - min + 1)) + min;
const randomChoice = (array) => array[Math.floor(Math.random() * array.length)];

// Convert date to ISO string matching Firestore Timestamp format
const toFirestoreDate = (date) => date.toISOString();

/**
 * Fix encoding issues with Spanish accents
 * Converts garbled characters to proper Spanish characters
 */
function fixSpanishEncoding(text) {
  if (!text) return text;
  
  // Map of common encoding issues to correct Spanish characters
  const replacements = [
    // Lowercase vowels with accents
    [/Ã¡/g, 'á'], [/Ã©/g, 'é'], [/Ã­/g, 'í'], [/Ã³/g, 'ó'], [/Ãº/g, 'ú'],
    // Uppercase vowels with accents
    [/Ã/g, 'Á'], [/Ã‰/g, 'É'], [/Ã/g, 'Í'], [/Ã"/g, 'Ó'], [/Ãš/g, 'Ú'],
    // Ñ and ñ
    [/Ã±/g, 'ñ'], [/Ã'/g, 'Ñ'],
    // U with dieresis
    [/Ã¼/g, 'ü'], [/Ãœ/g, 'Ü'],
    // Common combinations
    [/Ã³n/g, 'ón'], [/Ã±o/g, 'ño'], [/Ã­a/g, 'ía'],
    [/Ã¡s/g, 'ás'], [/Ã©n/g, 'én'],
    // Remove replacement characters
    [/\uFFFD/g, ''], // Unicode replacement character
    [/Â/g, ''], // Unwanted character
  ];
  
  let fixed = text;
  for (const [pattern, replacement] of replacements) {
    fixed = fixed.replace(pattern, replacement);
  }
  
  return fixed;
}

/**
 * Format address in Colombian style
 * Examples: "Calle 20 C Bis Sur #93-2", "Carrera 15 #45-67", "Diagonal 40 A Sur #12-34"
 */
function formatColombianAddress(rawAddress) {
  // Fix encoding first
  rawAddress = fixSpanishEncoding(rawAddress);
  
  // If address already looks formatted, return as is
  if (rawAddress.includes('Calle') || rawAddress.includes('Carrera') || rawAddress.includes('Diagonal')) {
    return rawAddress;
  }
  
  // Parse the raw address format from CSV (e.g., "KR 32 55 01 SUR", "CL 72 05 32")
  const parts = rawAddress.trim().split(/\s+/);
  
  let type = '';
  let mainNumber = '';
  let secondNumber = '';
  let thirdNumber = '';
  let suffix = '';
  let letter = '';
  let modifier = '';
  
  // Identify address type
  if (parts[0].startsWith('KR') || parts[0].startsWith('CR')) {
    type = 'Carrera';
  } else if (parts[0].startsWith('CL')) {
    type = 'Calle';
  } else if (parts[0].startsWith('DG') || parts[0].startsWith('DI')) {
    type = 'Diagonal';
  } else if (parts[0].startsWith('TV') || parts[0].startsWith('TR')) {
    type = 'Transversal';
  } else if (parts[0].startsWith('AV')) {
    type = 'Avenida';
  } else {
    type = 'Calle'; // Default
  }
  
  // Parse numbers and modifiers
  let idx = 1;
  mainNumber = parts[idx++] || randomInt(1, 200).toString();
  
  // Check for letter modifier (A, B, C, etc.)
  if (parts[idx] && /^[A-Z]$/i.test(parts[idx])) {
    letter = parts[idx++];
  }
  
  // Check for "BIS" modifier
  if (parts[idx] && parts[idx].toUpperCase().includes('BIS')) {
    modifier = 'Bis';
    idx++;
  }
  
  // Parse second and third numbers
  secondNumber = parts[idx++] || randomInt(1, 150).toString();
  thirdNumber = parts[idx++] || randomInt(1, 99).toString().padStart(2, '0');
  
  // Check for directional suffix (SUR, NORTE, ESTE, OESTE)
  for (let i = idx; i < parts.length; i++) {
    if (['SUR', 'NORTE', 'ESTE', 'OESTE'].includes(parts[i].toUpperCase())) {
      suffix = parts[i].charAt(0).toUpperCase() + parts[i].slice(1).toLowerCase();
    }
  }
  
  // Build formatted address
  let formatted = type;
  formatted += ' ' + mainNumber;
  if (letter) formatted += ' ' + letter.toUpperCase();
  if (modifier) formatted += ' ' + modifier;
  if (suffix) formatted += ' ' + suffix;
  formatted += ' #' + secondNumber + '-' + thirdNumber;
  
  return formatted;
}

// ===================== FETCH EXISTING MEDICAMENTOS =====================
async function fetchExistingMedicamentos() {
  console.log("💊 Fetching existing medicamentosGlobales from Firestore...");
  
  try {
    const medicamentosRef = db.collection('medicamentosGlobales');
    const snapshot = await medicamentosRef.get();
    
    const existingMedicamentos = {};
    const existingNames = new Set();
    
    snapshot.forEach(doc => {
      const data = doc.data();
      existingMedicamentos[doc.id] = data;
      existingNames.add(data.nombre.toLowerCase());
    });
    
    console.log(`   📂 Found ${Object.keys(existingMedicamentos).length} existing medications`);
    return { medicamentos: existingMedicamentos, names: existingNames };
  } catch (error) {
    console.error("   ⚠️  Error fetching medications:", error.message);
    return { medicamentos: {}, names: new Set() };
  }
}

// ===================== GENERATE MEDICAMENTOS GLOBALES =====================
async function generateMedicamentosGlobales() {
  console.log("📊 Generating medicamentosGlobales...");
  
  // Fetch existing medications
  const { medicamentos: existingMeds, names: existingNames } = await fetchExistingMedicamentos();
  
  // Find the highest existing ID number
  let maxIdNumber = 0;
  for (const id of Object.keys(existingMeds)) {
    const match = id.match(/med_(\d+)/);
    if (match) {
      maxIdNumber = Math.max(maxIdNumber, parseInt(match[1]));
    }
  }
  
  console.log(`   🔢 Starting from ID: med_${String(maxIdNumber + 1).padStart(3, '0')}`);
  
  const medicamentos = { ...existingMeds }; // Start with existing medications
  let generatedCount = 0;
  let attemptsCount = 0;
  const maxAttempts = CONFIG.numMedicamentosGlobales * 3; // Avoid infinite loop
  
  while (generatedCount < CONFIG.numMedicamentosGlobales && attemptsCount < maxAttempts) {
    attemptsCount++;
    const principio = randomChoice(MEDICINE_DATA.principiosActivos);
    const dosis = randomChoice([250, 500, 750, 1000, 10, 20, 50, 100]);
    const presentacion = randomChoice(MEDICINE_DATA.presentaciones);
    const nombre = `${principio} ${dosis}mg`;
    
    // Check if medication name already exists
    if (existingNames.has(nombre.toLowerCase())) {
      continue; // Skip duplicate
    }
    
    const id = `med_${String(maxIdNumber + generatedCount + 1).padStart(3, '0')}`;
    const contraindicacion1 = randomChoice(contraindicaciones);
    const contraindicacion2 = randomChoice([...contraindicaciones].filter(c => c !== contraindicacion1));
      
    medicamentos[id] = {
      nombre: nombre,
      principioActivo: principio,
      presentacion: presentacion,
      laboratorio: randomChoice(MEDICINE_DATA.laboratorios),
      descripcion: `Medicamento ${principio} ${dosis}mg en ${presentacion.toLowerCase()}. Indicado para el tratamiento de diversas condiciones de salud.`,
      contraindicaciones: [
       contraindicacion1,
       contraindicacion2,
      ],
      imagenUrl: faker.image.urlLoremFlickr({ category: 'medical' }),
    };
    
    existingNames.add(nombre.toLowerCase());
    generatedCount++;
  }
  
  console.log(`   ✅ Total medications: ${Object.keys(medicamentos).length} (${generatedCount} new, ${Object.keys(existingMeds).length} existing)`);
  return medicamentos;
}

// ===================== GENERATE PUNTOS FÍSICOS =====================
async function generatePuntosFisicos() {
  console.log("🏪 Generating puntosFisicos from real CSV data...");
  const puntosFisicos = {};
  
  // Parse real pharmacy data from CSV
  const realPharmacies = parsePharmacyCSV();
  
  // Use real pharmacies or fallback to generated ones
  const pharmaciesToUse = realPharmacies.length > 0 
    ? faker.helpers.shuffle(realPharmacies).slice(0, CONFIG.numPuntosFisicos)
    : [];
  
  // Prepare addresses for batch geocoding (only for real pharmacies)
  if (pharmaciesToUse.length > 0 && GEOCODING_CONFIG.enabled) {
    console.log(`   🌍 Geocoding ${pharmaciesToUse.length} pharmacy addresses...`);
    
    // Format addresses for geocoding service (expects array of objects with address and city)
    const addressesToGeocode = pharmaciesToUse.map(p => ({
      address: p.direccion,
      city: "Bogotá"
    }));
    
    // Batch geocode all addresses (uses cache and rate limiting)
    const geocodedResults = await geocodeAddresses(addressesToGeocode, (current, total, geocoded, cached, failed) => {
      if (current % 5 === 0 || current === total) {
        console.log(`   📍 Progress: ${current}/${total} (${geocoded} new, ${cached} cached, ${failed} failed)`);
      }
    });
    
    // Create pharmacies with geocoded coordinates
    for (let i = 0; i < pharmaciesToUse.length; i++) {
      const id = randomId();
      const pharmacy = pharmaciesToUse[i];
      const geocodedResult = geocodedResults[i];
      
      // Format address in Colombian style
      const formattedAddress = formatColombianAddress(pharmacy.direccion);
      
      // Use geocoded coordinates with fallback to localidad
      const ubicacion = getCoordinatesWithFallback(
        geocodedResult,
        pharmacy.localidad,
        LOCALIDAD_COORDINATES
      );
      
      puntosFisicos[id] = {
        nombre: pharmacy.nombre,
        direccion: formattedAddress, // Use formatted address
        telefono: pharmacy.telefono,
        localidad: pharmacy.localidad, // Add localidad as optional parameter
        // Firestore GeoPoint format - now with precise geocoded coordinates
        ubicacion: ubicacion,
        horario: pharmacy.abierto24h 
          ? "24 horas" 
          : randomChoice([
              "Lunes a Sábado 8:00am - 8:00pm",
              "Lunes a Domingo 7:00am - 10:00pm",
              "Lunes a Viernes 8:00am - 6:00pm"
            ]),
      };
    }
  } else {
    // Fallback to localidad-based coordinates if geocoding disabled
    for (let i = 0; i < pharmaciesToUse.length; i++) {
      const id = randomId();
      const pharmacy = pharmaciesToUse[i];
      
      // Format address in Colombian style
      const formattedAddress = formatColombianAddress(pharmacy.direccion);
      
      // Generate coordinates based on the pharmacy's localidad
      const ubicacion = getCoordinatesForLocalidad(pharmacy.localidad);
      
      puntosFisicos[id] = {
        nombre: pharmacy.nombre,
        direccion: formattedAddress, // Use formatted address
        telefono: pharmacy.telefono,
        localidad: pharmacy.localidad,
        ubicacion: ubicacion,
        horario: pharmacy.abierto24h 
          ? "24 horas" 
          : randomChoice([
              "Lunes a Sábado 8:00am - 8:00pm",
              "Lunes a Domingo 7:00am - 10:00pm",
              "Lunes a Viernes 8:00am - 6:00pm"
            ]),
      };
    }
  }
  
  // Fill remaining with generated pharmacies if needed
  const remaining = CONFIG.numPuntosFisicos - Object.keys(puntosFisicos).length;
  for (let i = 0; i < remaining; i++) {
    const id = randomId();
    const chain = randomChoice(PHARMACY_CHAINS);
    const num = randomInt(1, 999);
    
    // Generate formatted Colombian address
    const addressType = randomChoice(['Calle', 'Carrera', 'Avenida', 'Diagonal', 'Transversal']);
    const mainNum = randomInt(1, 200);
    const letter = Math.random() > 0.7 ? randomChoice(['A', 'B', 'C', 'D']) : '';
    const bis = Math.random() > 0.8 ? ' Bis' : '';
    const suffix = Math.random() > 0.5 ? randomChoice([' Sur', ' Norte', '']) : '';
    const secondNum = randomInt(1, 150);
    const thirdNum = randomInt(1, 99).toString().padStart(2, '0');
    const formattedAddress = `${addressType} ${mainNum}${letter ? ' ' + letter : ''}${bis}${suffix} #${secondNum}-${thirdNum}`;
    
    puntosFisicos[id] = {
      nombre: `${chain} ${num}`,
      direccion: formattedAddress,
      telefono: `601${randomInt(2000000, 9999999)}`,
      ubicacion: {
        _latitude: randomCoord(BOGOTA_CENTER.lat, COORD_RANGE),
        _longitude: randomCoord(BOGOTA_CENTER.lon, COORD_RANGE),
      },
      horario: randomChoice([
        "Lunes a Sábado 8:00am - 8:00pm",
        "Lunes a Domingo 7:00am - 10:00pm",
        "24 horas",
        "Lunes a Viernes 8:00am - 6:00pm"
      ]),
    };
  }
  
  console.log(`   ✅ Generated ${Object.keys(puntosFisicos).length} pharmacies (${pharmaciesToUse.length} from CSV)`);
  return puntosFisicos;
}

// ===================== GENERATE INVENTARIOS (subcollection) =====================
function generateInventarios(puntosFisicos, medicamentos) {
  console.log("📦 Generating inventarios (subcollections)...");
  const inventarios = {};
  const medIds = Object.keys(medicamentos);
  
  for (const [puntoId, punto] of Object.entries(puntosFisicos)) {
    inventarios[puntoId] = {};
    
    // Random number of medicines per pharmacy
    const numMedicines = randomInt(CONFIG.inventarioPorFarmacia.min, CONFIG.inventarioPorFarmacia.max);
    const selectedMeds = faker.helpers.shuffle(medIds).slice(0, numMedicines);
    
    for (const medId of selectedMeds) {
      const med = medicamentos[medId];
      const invId = medId; // Use same ID as medication for consistency
      
      inventarios[puntoId][invId] = {
        nombre: med.nombre,
        lote: `L${faker.string.alphanumeric(6).toUpperCase()}`,
        proveedor: med.laboratorio,
        fechaIngreso: toFirestoreDate(randomDate(new Date(2024, 0, 1), new Date())),
        fechaVencimiento: toFirestoreDate(randomDate(new Date(), new Date(2027, 11, 31))),
        precioUnidad: randomInt(500, 50000), // Price in cents (COP)
        stock: randomInt(0, 200),
        medicamentoRef: `/medicamentosGlobales/${medId}`, // Firestore reference path
      };
    }
  }
  
  console.log(`   ✅ Generated inventories for ${Object.keys(inventarios).length} pharmacies`);
  return inventarios;
}

// ===================== FETCH EXISTING USUARIOS =====================
async function fetchExistingUsuarios() {
  console.log("👥 Fetching existing usuarios from Firestore...");
  
  if (!CONFIG.useExistingUsers) {
    console.log("   ⏭️  Skipping (useExistingUsers is false)");
    return {};
  }
  
  try {
    const usuariosRef = db.collection('usuarios');
    const snapshot = await usuariosRef.limit(CONFIG.maxUsersToFetch).get();
    
    if (snapshot.empty) {
      console.log("   ⚠️  No existing users found in Firestore");
      return {};
    }
    
    const usuarios = {};
    snapshot.forEach(doc => {
      const data = doc.data();
      usuarios[doc.id] = {
        uid: doc.id,
        nombre: data.nombre || faker.person.fullName(),
        email: data.email || faker.internet.email().toLowerCase(),
        telefono: data.telefono || `3${randomInt(100000000, 999999999)}`,
        direccion: data.direccion || `Cra ${randomInt(1, 50)} #${randomInt(1, 100)}-${randomInt(1, 99)}`,
        city: data.city || "Bogotá",
        department: data.department || "Bogotá D.C.",
        zipCode: data.zipCode || "110111",
        preferencias: data.preferencias || {
          modoEntregaPreferido: randomChoice(["domicilio", "recogida"]),
          notificaciones: faker.datatype.boolean(),
        },
        createdAt: data.createdAt ? data.createdAt : toFirestoreDate(randomDate(new Date(2024, 0, 1), new Date())),
      };
    });
    
    console.log(`   ✅ Fetched ${Object.keys(usuarios).length} existing users`);
    return usuarios;
  } catch (error) {
    console.error("   ❌ Error fetching users:", error.message);
    return {};
  }
}

// ===================== GENERATE PRESCRIPCIONES (subcollection) =====================
function generatePrescripciones(usuarios, medicamentos) {
  console.log("📋 Generating prescripciones (subcollections)...");
  const prescripciones = {};
  const medIds = Object.keys(medicamentos);
  
  for (const [userId, user] of Object.entries(usuarios)) {
    prescripciones[userId] = {};
    
    const numPrescripciones = randomInt(
      CONFIG.prescripcionesPorUsuario.min,
      CONFIG.prescripcionesPorUsuario.max
    );
    
    for (let i = 0; i < numPrescripciones; i++) {
      const presId = `pres_${randomId()}`;
      const fechaCreacion = randomDate(new Date(2024, 6, 1), new Date());
      const activa = i === 0; // Only first prescription is active
      
      prescripciones[userId][presId] = {
        id: presId,
        fechaCreacion: toFirestoreDate(fechaCreacion),
        diagnostico: faker.lorem.words(3),
        medico: `Dr. ${faker.person.lastName()}`,
        activa: activa,
      };
    }
  }
  
  console.log(`   ✅ Generated prescriptions for ${Object.keys(prescripciones).length} users`);
  return prescripciones;
}

// ===================== GENERATE MEDICAMENTOS PRESCRIPCION (nested subcollection) =====================
function generateMedicamentosPrescripcion(prescripciones, medicamentos) {
  console.log("💊 Generating medicamentos within prescripciones...");
  const medicamentosPrescripcion = {};
  const medIds = Object.keys(medicamentos);
  
  for (const [userId, userPrescripciones] of Object.entries(prescripciones)) {
    medicamentosPrescripcion[userId] = {};
    
    for (const [presId, prescripcion] of Object.entries(userPrescripciones)) {
      medicamentosPrescripcion[userId][presId] = {};
      
      const numMeds = randomInt(
        CONFIG.medicamentosPorPrescripcion.min,
        CONFIG.medicamentosPorPrescripcion.max
      );
      const selectedMeds = faker.helpers.shuffle(medIds).slice(0, numMeds);
      
      for (const medId of selectedMeds) {
        const med = medicamentos[medId];
        const fechaInicio = new Date(prescripcion.fechaCreacion);
        const duracionDias = randomChoice([7, 15, 30, 60, 90]);
        const fechaFin = new Date(fechaInicio);
        fechaFin.setDate(fechaFin.getDate() + duracionDias);
        
        medicamentosPrescripcion[userId][presId][medId] = {
          id: medId,
          medicamentoRef: `/medicamentosGlobales/${medId}`,
          nombre: med.nombre,
          dosisMg: parseInt(med.nombre.match(/\d+/)?.[0] || "500"),
          frecuenciaHoras: randomChoice([6, 8, 12, 24]),
          duracionDias: duracionDias,
          fechaInicio: toFirestoreDate(fechaInicio),
          fechaFin: toFirestoreDate(fechaFin),
          observaciones: faker.lorem.sentence(),
          activo: prescripcion.activa,
          userId: userId,
          prescripcionId: presId,
        };
      }
    }
  }
  
  console.log(`   ✅ Generated prescription medications`);
  return medicamentosPrescripcion;
}

// ===================== GENERATE PEDIDOS (subcollection) =====================
function generatePedidos(usuarios, prescripciones, puntosFisicos) {
  console.log("🛒 Generating pedidos (subcollections)...");
  const pedidos = {};
  const puntoIds = Object.keys(puntosFisicos);
  
  for (const [userId, user] of Object.entries(usuarios)) {
    pedidos[userId] = {};
    
    const numPedidos = randomInt(
      CONFIG.pedidosPorUsuario.min,
      CONFIG.pedidosPorUsuario.max
    );
    
    const userPrescIds = Object.keys(prescripciones[userId] || {});
    
    for (let i = 0; i < numPedidos; i++) {
      const pedidoId = `ped_${randomId()}`;
      const fechaPedido = randomDate(new Date(2024, 8, 1), new Date());
      const fechaEntrega = new Date(fechaPedido);
      fechaEntrega.setDate(fechaEntrega.getDate() + randomInt(1, 5));
      
      pedidos[userId][pedidoId] = {
        id: pedidoId,
        prescripcionId: userPrescIds.length > 0 ? randomChoice(userPrescIds) : "",
        puntoFisicoId: randomChoice(puntoIds),
        tipoEntrega: randomChoice(["domicilio", "recogida"]),
        direccionEntrega: user.direccion,
        estado: randomChoice(["pendiente", "en_proceso", "entregado", "cancelado"]),
        fechaPedido: toFirestoreDate(fechaPedido),
        fechaEntrega: toFirestoreDate(fechaEntrega),
      };
    }
  }
  
  console.log(`   ✅ Generated orders for users`);
  return pedidos;
}

// ===================== GENERATE MEDICAMENTOS PEDIDO (nested subcollection) =====================
function generateMedicamentosPedido(pedidos, medicamentos) {
  console.log("💊 Generating medicamentos within pedidos...");
  const medicamentosPedido = {};
  const medIds = Object.keys(medicamentos);
  
  for (const [userId, userPedidos] of Object.entries(pedidos)) {
    medicamentosPedido[userId] = {};
    
    for (const [pedidoId, pedido] of Object.entries(userPedidos)) {
      medicamentosPedido[userId][pedidoId] = {};
      
      const numMeds = randomInt(1, 3);
      const selectedMeds = faker.helpers.shuffle(medIds).slice(0, numMeds);
      
      for (const medId of selectedMeds) {
        const med = medicamentos[medId];
        const cantidad = randomInt(1, 10);
        const precioUnitario = randomInt(1000, 50000);
        
        medicamentosPedido[userId][pedidoId][medId] = {
          id: medId,
          medicamentoRef: `/medicamentosGlobales/${medId}`,
          nombre: med.nombre,
          cantidad: cantidad,
          precioUnitario: precioUnitario,
          total: cantidad * precioUnitario,
          userId: userId,
          pedidoId: pedidoId,
        };
      }
    }
  }
  
  console.log(`   ✅ Generated order medications`);
  return medicamentosPedido;
}

// ===================== GENERATE MEDICAMENTOS USUARIO (subcollection) =====================
function generateMedicamentosUsuario(usuarios, medicamentos, prescripciones, medicamentosPrescripcion) {
  console.log("💊 Generating medicamentosUsuario (subcollections)...");
  const medicamentosUsuario = {};
  
  for (const [userId, user] of Object.entries(usuarios)) {
    medicamentosUsuario[userId] = {};
    
    // First, collect ALL medications from user's prescriptions
    const prescriptionMeds = new Set();
    const prescriptionMedDetails = new Map(); // Store prescription details for each med
    
    if (prescripciones[userId] && medicamentosPrescripcion[userId]) {
      for (const [presId, prescripcion] of Object.entries(prescripciones[userId])) {
        if (medicamentosPrescripcion[userId][presId]) {
          for (const [medId, medData] of Object.entries(medicamentosPrescripcion[userId][presId])) {
            prescriptionMeds.add(medId);
            // Store prescription info for this medication
            if (!prescriptionMedDetails.has(medId)) {
              prescriptionMedDetails.set(medId, {
                prescripcionId: presId,
                dosis: medData.dosis,
                frecuenciaHoras: medData.frecuenciaHoras,
                fechaInicio: medData.fechaInicio,
                fechaFin: medData.fechaFin,
                activo: prescripcion.activa, // Use prescription active status
              });
            }
          }
        }
      }
    }
    
    // Add all medications from prescriptions
    let activeCount = 0;
    for (const medId of prescriptionMeds) {
      const med = medicamentos[medId];
      const prescDetails = prescriptionMedDetails.get(medId);
      
      if (med && prescDetails) {
        medicamentosUsuario[userId][medId] = {
          id: medId,
          medicamentoRef: `/medicamentosGlobales/${medId}`,
          nombre: med.nombre,
          dosisMg: parseInt(med.nombre.match(/\d+/)?.[0] || "500"),
          frecuenciaHoras: prescDetails.frecuenciaHoras,
          activo: prescDetails.activo && activeCount === 0, // First from active prescription is active
          prescripcionId: prescDetails.prescripcionId,
          fechaInicio: prescDetails.fechaInicio,
          fechaFin: prescDetails.fechaFin,
        };
        
        if (prescDetails.activo && activeCount === 0) {
          activeCount++;
        }
      }
    }
    
    // Optionally add a few extra medications (not from prescriptions)
    // This represents medications the user might be taking without a prescription in the system
    const extraMedsCount = randomInt(0, 2); // 0-2 additional medications
    const allMedIds = Object.keys(medicamentos);
    const availableMeds = allMedIds.filter(id => !prescriptionMeds.has(id));
    const extraMeds = faker.helpers.shuffle(availableMeds).slice(0, extraMedsCount);
    
    for (const medId of extraMeds) {
      const med = medicamentos[medId];
      const fechaInicio = randomDate(new Date(2024, 6, 1), new Date());
      const duracionDias = randomChoice([30, 60, 90, 180]);
      const fechaFin = new Date(fechaInicio);
      fechaFin.setDate(fechaFin.getDate() + duracionDias);
      
      medicamentosUsuario[userId][medId] = {
        id: medId,
        medicamentoRef: `/medicamentosGlobales/${medId}`,
        nombre: med.nombre,
        dosisMg: parseInt(med.nombre.match(/\d+/)?.[0] || "500"),
        frecuenciaHoras: randomChoice([6, 8, 12, 24]),
        activo: false, // Extra medications are not active by default
        prescripcionId: "", // No prescription for these
        fechaInicio: toFirestoreDate(fechaInicio),
        fechaFin: toFirestoreDate(fechaFin),
      };
    }
  }
  
  console.log(`   ✅ Generated user medications for ${Object.keys(medicamentosUsuario).length} users`);
  return medicamentosUsuario;
}

// ===================== MAIN GENERATION =====================
async function generateAllData() {
  console.log("🌱 Starting mock data generation...\n");
  
  // Initialize Firebase (needed for fetching existing data)
  console.log("🔥 Initializing Firebase Admin SDK...");
  initializeFirebase();
  
  // 1. Generate independent collections (checking for existing data)
  const medicamentosGlobales = await generateMedicamentosGlobales(); // Now checks existing
  const puntosFisicos = await generatePuntosFisicos(); // Already async for geocoding
  
  // 2. Fetch existing users (don't generate new ones, only use existing)
  const usuarios = await fetchExistingUsuarios();
  
  // If no users found, skip user-related data
  if (Object.keys(usuarios).length === 0) {
    console.log("\n⚠️  No users available. Skipping user-related data generation.");
    return {
      medicamentosGlobales,
      puntosFisicos,
      inventarios: generateInventarios(puntosFisicos, medicamentosGlobales),
      usuarios: {},
      prescripciones: {},
      medicamentosPrescripcion: {},
      pedidos: {},
      medicamentosPedido: {},
      medicamentosUsuario: {},
    };
  }
  
  // 3. Generate dependent collections (only subcollections for existing users)
  const inventarios = generateInventarios(puntosFisicos, medicamentosGlobales);
  const prescripciones = generatePrescripciones(usuarios, medicamentosGlobales);
  const medicamentosPrescripcion = generateMedicamentosPrescripcion(prescripciones, medicamentosGlobales);
  const pedidos = generatePedidos(usuarios, prescripciones, puntosFisicos);
  const medicamentosPedido = generateMedicamentosPedido(pedidos, medicamentosGlobales);
  const medicamentosUsuario = generateMedicamentosUsuario(usuarios, medicamentosGlobales, prescripciones, medicamentosPrescripcion);
  
  // 4. Return data structure (usuarios are NOT included to avoid overwriting)
  const fullData = {
    medicamentosGlobales,
    puntosFisicos,
    inventarios, // Organized by puntoFisicoId
    usuarios: {}, // Empty - we don't want to overwrite existing users
    prescripciones, // Organized by userId
    medicamentosPrescripcion, // Organized by userId -> prescripcionId
    pedidos, // Organized by userId
    medicamentosPedido, // Organized by userId -> pedidoId
    medicamentosUsuario, // Organized by userId
  };
  
  return fullData;
}

// ===================== SAVE TO FILE =====================
(async () => {
  try {
    const data = await generateAllData();
    const filename = "mock_data.json";
    
    writeFileSync(filename, JSON.stringify(data, null, 2), "utf8");
    
    console.log(`\n✅ Mock data generated successfully!`);
    console.log(`📄 File: ${filename}`);
    console.log(`📊 Statistics:`);
    console.log(`   - Medicamentos Globales: ${Object.keys(data.medicamentosGlobales).length}`);
    console.log(`   - Puntos Físicos: ${Object.keys(data.puntosFisicos).length}`);
    console.log(`   - Usuarios: (using existing - not overwritten)`);
    console.log(`   - Total Prescripciones: ${Object.values(data.prescripciones).reduce((sum, p) => sum + Object.keys(p).length, 0)}`);
    console.log(`   - Total Pedidos: ${Object.values(data.pedidos).reduce((sum, p) => sum + Object.keys(p).length, 0)}`);
    console.log(`\n💡 Note: Existing users will not be overwritten. Only subcollections are generated.`);
    
    // Close Firebase connection
    if (admin.apps.length > 0) {
      await admin.app().delete();
      console.log(`🔥 Firebase connection closed`);
    }
    
    process.exit(0);
  } catch (error) {
    console.error("❌ Error generating mock data:", error);
    
    // Close Firebase connection on error
    if (admin.apps.length > 0) {
      await admin.app().delete();
    }
    
    process.exit(1);
  }
})();
