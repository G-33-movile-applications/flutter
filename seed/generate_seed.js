// generateFirestoreMock.js
import { writeFileSync } from "fs";

// ===================== CONFIGURACIÓN =====================
//    "6NfEXvyZbZZpZs8wqcL05BpSO7r1",
//"ThDpG1WVAdQ5BFBWkXsSlO0IGzU2",
//"xTNWOUMQ19Udl7DCyfDPovIFVO82",
//"2QUsa2vgcKQlqMAJ9WbuXFoYIN72",
//"OG20xG1r1AVUCfeOpCE2uaKB95E3",
//"xI9v6LjpeYORwNz9xJwQ7rnbv2p2",
//"iVgLkJimWQNM9jdo20D76O23VDF2",

const userIds = [
    "0g6kwSrnp1aDk3rmE2OgHRYRgWZ2",

];
const farmacies = [
    "Farmatodo",
    "Cruz Verde",
    "Walgreens",
    "CVS Health",
    "Farmacias Similares",
    "Farmacias del Ahorro",
    "Droguerías La Rebaja",
    "Cafam",
];
const randomId = () => Math.random().toString(36).substring(2, 15);
const randomDate = (start = new Date(2025, 8, 1), end = new Date(2025, 10, 30)) =>
    new Date(start.getTime() + Math.random() * (end.getTime() - start.getTime()))
        .toISOString();

const randomCoord = (center, range = 0.02) =>
    center + (Math.random() - 0.5) * range;
// 4.667874, -74.135952 casas
// centro 4.711, -74.0721
// ===================== DATOS BASE =====================
const baseCoords = { lat: 4.711, lon: -74.0721 }; // Bogotá centro
const medicineNames = [
    "Ibuprofeno 400mg",
    "Paracetamol 500mg",
    "Amoxicilina 875mg",
    "Loratadina 10mg",
    "Omeprazol 20mg",
    "Losartán 50mg",
    "Atorvastatina 20mg",
    "Metformina 850mg",
    "Salbutamol Inhalador",
    "Ácido Fólico 5mg",
];

const numprescripciones = 12;
const farmacias = farmacies.length;
const medicinesNames = medicineNames;
// ===================== CREACIÓN DE ENTIDADES =====================
const medicamentos = {};
medicinesNames.forEach((name, idx) => {
    const id = `med_${idx + 1}`;
    medicamentos[id] = {
        nombre: name + ` ${Math.floor(Math.random() * 1000 + 1)}mg`,
        descripcion: `Medicamento ${name} usado comúnmente para tratar diversas condiciones.`,
        dosisMg: `${Math.floor(Math.random() * 3000 + 1)} `,
        esRestringido: Math.random() < 0.5 ? false : true,
        tipo: "tabletas",
    };
});

const puntos_fisicos = {};
for (let i = 0; i < farmacias; i++) {
    const id = randomId();
    puntos_fisicos[id] = {
        cadena: `${farmacies[i % farmacies.length]}`,
        nombre: `Punto Físico ${i + 1} ${Math.floor(Math.random() * 100 + 1)}`,
        direccion: `Cra ${Math.floor(Math.random() * 30 + 1)} # ${Math.floor(
            Math.random() * 20 + 1
        )}-${Math.floor(Math.random() * 50 + 1)}`,
        latitud: randomCoord(baseCoords.lat),
        longitud: randomCoord(baseCoords.lon),
        horarioAtencion: "Lunes a Sábado 8:00 a.m. - 8:00 p.m.",
        diasAtencion: "Lunes a Sábado",
    };
}

const medicamento_punto_fisico = {};
Object.keys(puntos_fisicos).forEach((pfId) => {
    const meds = Object.keys(medicamentos)
        .sort(() => 0.5 - Math.random())
        .slice(0, 4);
    meds.forEach((medId) => {
        const id = randomId();
        medicamento_punto_fisico[id] = {
            puntoFisicoId: pfId,
            medicamentoId: medId,
            cantidad: Math.floor(Math.random() * 50 + 10),
            fechaActualizacion: randomDate(),
            id: id,
        };
    });
});

const prescripciones = {};
for (let i = 0; i < numprescripciones; i++) {
    const id = randomId();
    const userId = userIds[Math.floor(Math.random() * userIds.length)];
    const meds = Object.keys(medicamentos)
        .sort(() => 0.5 - Math.random())
        .slice(0, Math.floor(Math.random() * 3) + 1)
        .map((medId) => medicamentos[medId]); // Guarda el objeto completo

    prescripciones[id] = {
        id,
        userId,
        fechaEmision: randomDate(),
        recetadoPor: `Dr. ${["Gómez", "Rodríguez", "Martínez", "Sánchez"][Math.floor(Math.random() * 4)]
            }`,
        medicamentos: meds,
        pedidoId: null, // Se llenará cuando se cree el pedido
    };

}

const pedidos = {};
Object.keys(prescripciones).forEach((prescId) => {
    const id = randomId();
    const presc = prescripciones[prescId];
    const userId = presc.userId;

    const pfId = Object.keys(puntos_fisicos)[
        Math.floor(Math.random() * Object.keys(puntos_fisicos).length)
    ];

    const pedido = {
        id,
        usuarioId: userId,
        puntoFisicoId: pfId,
        prescripcion: presc, // Guarda todo el objeto de prescripción
        direccionEntrega: `Cra ${Math.floor(Math.random() * 30 + 1)} # ${Math.floor(
            Math.random() * 30 + 1
        )}-${Math.floor(Math.random() * 50 + 1)}`,
        fechaDespacho: randomDate(),
        fechaEntrega: randomDate(),
        entregaEnTienda: Math.random() < 0.5,
        entregado: Math.random() < 0.5,
    };

    pedidos[id] = pedido;

    // Vincular el pedido a la prescripción
    prescripciones[prescId].pedidoId = id;
});
// ===================== UNIR EN JSON FINAL =====================
const fullData = {
    puntos_fisicos,
    medicamentos,
    medicamento_punto_fisico,
    prescripciones,
    pedidos,
};
const name = "mock_firestore_data_new.json";
// ===================== GUARDAR ARCHIVO =====================
writeFileSync(name, JSON.stringify(fullData, null, 2), "utf8");
console.log(`Archivo ${name} generado exitosamente.`);
