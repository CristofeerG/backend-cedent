"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
const client_1 = require("@prisma/client");
const csvParser = require("csv-parser");
const fs = __importStar(require("fs"));
const path = __importStar(require("path"));
const prisma = new client_1.PrismaClient();
async function leerCsv(rutaArchivo) {
    return new Promise((resolver, rechazar) => {
        const filas = [];
        fs.createReadStream(rutaArchivo)
            .pipe(csvParser())
            .on('data', (fila) => filas.push(fila))
            .on('end', () => resolver(filas))
            .on('error', rechazar);
    });
}
async function sembrarKits() {
    const rutaCsv = path.join(__dirname, '..', 'kits.csv');
    console.log(`Leyendo CSV desde: ${rutaCsv}`);
    const filas = await leerCsv(rutaCsv);
    console.log(`Filas leídas: ${filas.length}`);
    console.log('\nLimpiando tablas detalle_kit y kits...');
    await prisma.movimientos.updateMany({
        where: { id_kit: { not: null } },
        data: { id_kit: null },
    });
    await prisma.detalle_kit.deleteMany();
    await prisma.kits.deleteMany();
    console.log('Tablas limpiadas.');
    const grupos = filas.reduce((acumulador, fila) => {
        const procedimiento = fila.PROCEDIMIENTO?.trim();
        if (!procedimiento)
            return acumulador;
        if (!acumulador[procedimiento])
            acumulador[procedimiento] = [];
        acumulador[procedimiento].push(fila);
        return acumulador;
    }, {});
    const procedimientos = Object.keys(grupos);
    console.log(`\nProcedimientos encontrados: ${procedimientos.length} (${procedimientos.join(', ')})`);
    let kitsInsertados = 0;
    let detallesInsertados = 0;
    let productosNoEncontrados = 0;
    for (const [nombreProcedimiento, items] of Object.entries(grupos)) {
        const nuevoKit = await prisma.kits.create({
            data: { nombre_procedimiento: nombreProcedimiento },
        });
        kitsInsertados++;
        console.log(`\n[Kit] "${nombreProcedimiento}" -> id_kit: ${nuevoKit.id_kit}`);
        for (const item of items) {
            const nombreMaterial = item.NOMBRE_MATERIAL?.trim();
            if (!nombreMaterial)
                continue;
            const producto = await prisma.productos.findFirst({
                where: { nombre_mat: nombreMaterial },
            });
            if (!producto) {
                console.warn(`  [OMITIDO] Producto no encontrado: "${nombreMaterial}"`);
                productosNoEncontrados++;
                continue;
            }
            await prisma.detalle_kit.create({
                data: {
                    id_kit: nuevoKit.id_kit,
                    id_producto: producto.id_producto,
                    cantidad_estandar: parseFloat(item.CONSUMO),
                },
            });
            detallesInsertados++;
            console.log(`  [OK] ${nombreMaterial} (id: ${producto.id_producto}) x${item.CONSUMO}`);
        }
    }
    console.log(`
Seed finalizado:
  - Kits insertados:     ${kitsInsertados}
  - Detalles insertados: ${detallesInsertados}
  - Productos omitidos:  ${productosNoEncontrados}
`);
}
sembrarKits()
    .catch((error) => {
    console.error('Error fatal en seed-kits:', error);
    process.exit(1);
})
    .finally(() => prisma.$disconnect());
//# sourceMappingURL=seed-kits.js.map