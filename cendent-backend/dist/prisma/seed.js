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
const ID_SUCURSAL = 1;
const ID_USUARIO = 1;
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
function generarCodigoLote(subcategoria, anio, idProducto) {
    const prefijo = subcategoria.trim().substring(0, 4).toUpperCase();
    const idFormateado = String(idProducto).padStart(3, '0');
    return `${prefijo}-${anio}-${idFormateado}`;
}
async function sembrar() {
    const rutaCsv = path.join(__dirname, 'inventario_hoja2.csv');
    const filas = await leerCsv(rutaCsv);
    const anioActual = new Date().getFullYear();
    let insertados = 0;
    let omitidos = 0;
    let errores = 0;
    console.log(`Iniciando seed con ${filas.length} registros del CSV...`);
    for (const fila of filas) {
        const nombreMat = fila.NOMBRE_MATERIAL?.trim();
        if (!nombreMat)
            continue;
        try {
            const factorConv = parseFloat(fila.FACTOR_CONV) || 1;
            const stockCsv = parseFloat(fila.STOCK_ACTUAL) || 0;
            const stockActual = stockCsv * factorConv;
            const costoUnit = parseFloat(fila.COSTO_UNIT) || 0;
            const stockMin = parseFloat(fila.STOCK_MIN) || 0;
            const fechaVenc = fila.FECHA_VENC
                ? new Date(fila.FECHA_VENC)
                : new Date('2099-12-31');
            const productoExistente = await prisma.productos.findFirst({
                where: { nombre_mat: nombreMat },
            });
            if (productoExistente) {
                omitidos++;
                continue;
            }
            const nuevoProducto = await prisma.productos.create({
                data: {
                    nombre_mat: nombreMat,
                    categoria: fila.CATEGORIA?.trim() || null,
                    subcategoria: fila.SUBCATEGORIA?.trim() || null,
                    unidad_medida: fila.UNIDAD_MEDIDA?.trim(),
                    stock_min: stockMin,
                },
            });
            const idProducto = nuevoProducto.id_producto;
            const codigoLote = generarCodigoLote(fila.SUBCATEGORIA || '', anioActual, idProducto);
            const nuevoLote = await prisma.lotes.create({
                data: {
                    id_producto: idProducto,
                    id_sucursal: ID_SUCURSAL,
                    codigo_lote: codigoLote,
                    stock_actual: stockActual,
                    costo_unit: costoUnit,
                    fecha_venc: fechaVenc,
                },
            });
            await prisma.movimientos.create({
                data: {
                    id_usuario: ID_USUARIO,
                    id_lote: nuevoLote.id_lote,
                    id_kit: null,
                    cantidad: stockActual,
                    tipo_mov: 'INGRESO_INICIAL',
                },
            });
            insertados++;
            console.log(`[OK] ${nombreMat} | Lote: ${codigoLote} | Stock: ${stockActual}`);
        }
        catch (error) {
            errores++;
            console.error(`[ERROR] Fila "${nombreMat}":`, error.message);
        }
    }
    console.log(`\nSeed finalizado: ${insertados} insertados, ${omitidos} omitidos (ya existían), ${errores} errores.`);
}
sembrar()
    .catch((error) => {
    console.error('Error fatal en el seed:', error);
    process.exit(1);
})
    .finally(() => prisma.$disconnect());
//# sourceMappingURL=seed.js.map