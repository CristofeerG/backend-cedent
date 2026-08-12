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
const brain = __importStar(require("brain.js"));
const fs = __importStar(require("fs"));
const path = __importStar(require("path"));
const prisma = new client_1.PrismaClient();
const ITERACIONES = 500;
const UMBRAL_ERROR = 0.01;
const MIN_PUNTOS_VALIDACION = 28;
function suavizarSerie(serie) {
    return serie.map((_, i) => {
        const inicio = Math.max(0, i - 2);
        const fin = Math.min(serie.length - 1, i + 2);
        const ventana = serie.slice(inicio, fin + 1);
        return ventana.reduce((s, v) => s + v, 0) / ventana.length;
    });
}
async function obtenerEgresos(idSucursal) {
    return prisma.movimientos.findMany({
        where: {
            tipo_mov: { in: ['EGRESO_KIT', 'EGRESO_DIRECTO', 'SALIDA_TRANSFERENCIA'] },
            lotes: { id_sucursal: idSucursal },
        },
        include: {
            lotes: {
                include: { productos: { select: { nombre_mat: true } } },
            },
        },
        orderBy: { fecha_hora: 'asc' },
    });
}
function agrupar(egresos) {
    const mapaConsumos = new Map();
    const nombreProducto = new Map();
    for (const mov of egresos) {
        if (!mov.lotes || mov.lotes.id_producto === null)
            continue;
        const idProducto = mov.lotes.id_producto;
        const fecha = (mov.fecha_hora ?? new Date()).toISOString().slice(0, 10);
        const cantidad = Number(mov.cantidad);
        if (!mapaConsumos.has(idProducto)) {
            mapaConsumos.set(idProducto, new Map());
            nombreProducto.set(idProducto, mov.lotes.productos?.nombre_mat ?? `prod_${idProducto}`);
        }
        const mapaFecha = mapaConsumos.get(idProducto);
        mapaFecha.set(fecha, (mapaFecha.get(fecha) ?? 0) + cantidad);
    }
    return { mapaConsumos, nombreProducto };
}
function construirSerie(mapaFecha) {
    const fechas = Array.from(mapaFecha.keys()).sort();
    if (fechas.length >= 2) {
        const cursor = new Date(fechas[0]);
        const ultima = new Date(fechas[fechas.length - 1]);
        while (cursor <= ultima) {
            const key = cursor.toISOString().slice(0, 10);
            if (!mapaFecha.has(key))
                mapaFecha.set(key, 0);
            cursor.setDate(cursor.getDate() + 1);
        }
    }
    return Array.from(mapaFecha.keys())
        .sort()
        .map((f) => mapaFecha.get(f));
}
function mae(real, predicho) {
    const n = Math.min(real.length, predicho.length);
    if (n === 0)
        return 0;
    return real.slice(0, n).reduce((acc, v, i) => acc + Math.abs(v - predicho[i]), 0) / n;
}
function rmse(real, predicho) {
    const n = Math.min(real.length, predicho.length);
    if (n === 0)
        return 0;
    const mse = real.slice(0, n).reduce((acc, v, i) => acc + (v - predicho[i]) ** 2, 0) / n;
    return Math.sqrt(mse);
}
function precisionDireccional(real, predicho) {
    const n = Math.min(real.length, predicho.length);
    if (n < 2)
        return 0;
    let aciertos = 0;
    for (let i = 1; i < n; i++) {
        const dirReal = real[i] - real[i - 1];
        const dirPred = predicho[i] - predicho[i - 1];
        if ((dirReal >= 0 && dirPred >= 0) || (dirReal < 0 && dirPred < 0))
            aciertos++;
    }
    return (aciertos / (n - 1)) * 100;
}
async function validarSucursal(idSucursal, nomSucursal) {
    console.log(`  → Procesando "${nomSucursal}"...`);
    const egresos = await obtenerEgresos(idSucursal);
    const { mapaConsumos, nombreProducto } = agrupar(egresos);
    const validados = [];
    let omitidos = 0;
    for (const [idProducto, mapaFecha] of mapaConsumos.entries()) {
        const serie = construirSerie(mapaFecha);
        if (serie.length < MIN_PUNTOS_VALIDACION) {
            omitidos++;
            continue;
        }
        const max = Math.max(...serie);
        if (max === 0) {
            omitidos++;
            continue;
        }
        const splitIdx = Math.floor(serie.length * 0.8);
        const trainSerie = serie.slice(0, splitIdx);
        const valActual = serie.slice(splitIdx);
        const valLen = valActual.length;
        if (valLen < 2) {
            omitidos++;
            continue;
        }
        const trainMax = Math.max(...trainSerie);
        if (trainMax === 0) {
            omitidos++;
            continue;
        }
        const trainNorm = trainSerie.map((v) => v / trainMax);
        const trainSmooth = suavizarSerie(trainNorm);
        try {
            const red = new brain.recurrent.LSTMTimeStep({
                inputSize: 1,
                hiddenLayers: [10, 5],
                outputSize: 1,
            });
            const resultado = red.train([trainSmooth], {
                iterations: ITERACIONES,
                errorThresh: UMBRAL_ERROR,
                log: false,
            });
            const forecastNorm = red.forecast(trainSmooth, valLen);
            const forecastActual = forecastNorm.map((v) => Math.max(0, v * trainMax));
            validados.push({
                nombre: nombreProducto.get(idProducto) ?? `prod_${idProducto}`,
                mae: mae(valActual, forecastActual),
                rmse: rmse(valActual, forecastActual),
                dirAcc: precisionDireccional(valActual, forecastActual),
                errorEntrenamiento: resultado.error ?? 0,
                puntosHistoricos: serie.length,
            });
        }
        catch {
            omitidos++;
        }
    }
    return { nombre: nomSucursal, validados, omitidos };
}
function formatear(n, dec) {
    return n.toFixed(dec).padStart(6);
}
function generarReporte(resultados) {
    const lineas = [];
    lineas.push('══════════════════════════════════════════════════════');
    lineas.push('  VALIDACIÓN DEL MODELO LSTM — SISTEMA CENDENT');
    lineas.push('══════════════════════════════════════════════════════');
    lineas.push('');
    let totalValidados = 0;
    let sumMae = 0;
    let sumRmse = 0;
    let sumDir = 0;
    for (const r of resultados) {
        const n = r.validados.length;
        const avgMae = n > 0 ? r.validados.reduce((a, p) => a + p.mae, 0) / n : 0;
        const avgRmse = n > 0 ? r.validados.reduce((a, p) => a + p.rmse, 0) / n : 0;
        const avgDir = n > 0 ? r.validados.reduce((a, p) => a + p.dirAcc, 0) / n : 0;
        const avgErr = n > 0 ? r.validados.reduce((a, p) => a + p.errorEntrenamiento, 0) / n : 0;
        lineas.push(`  Sucursal: ${r.nombre}`);
        lineas.push('  ─────────────────────────────────────────────────');
        lineas.push(`  Productos validados        : ${String(n).padStart(4)}`);
        lineas.push(`  Productos omitidos (< ${MIN_PUNTOS_VALIDACION}d) : ${String(r.omitidos).padStart(4)}`);
        lineas.push(`  MAE promedio               : ${formatear(avgMae, 2)} u/día`);
        lineas.push(`  RMSE promedio              : ${formatear(avgRmse, 2)} u/día`);
        lineas.push(`  Precisión direccional      : ${formatear(avgDir, 1)} %`);
        lineas.push(`  Error de entrenamiento avg :${formatear(avgErr, 4)}`);
        lineas.push('');
        totalValidados += n;
        sumMae += avgMae * n;
        sumRmse += avgRmse * n;
        sumDir += avgDir * n;
    }
    const globalMae = totalValidados > 0 ? sumMae / totalValidados : 0;
    const globalRmse = totalValidados > 0 ? sumRmse / totalValidados : 0;
    const globalDir = totalValidados > 0 ? sumDir / totalValidados : 0;
    lineas.push('──────────────────────────────────────────────────');
    lineas.push('  RESUMEN GLOBAL');
    lineas.push('──────────────────────────────────────────────────');
    lineas.push(`  Total productos validados  : ${String(totalValidados).padStart(4)}`);
    lineas.push(`  MAE global                 : ${formatear(globalMae, 2)} u/día`);
    lineas.push(`  RMSE global                : ${formatear(globalRmse, 2)} u/día`);
    lineas.push(`  Precisión direccional      : ${formatear(globalDir, 1)} %`);
    lineas.push('══════════════════════════════════════════════════════');
    lineas.push(`  Generado: ${new Date().toLocaleString('es-VE', { timeZone: 'America/Caracas' })}`);
    lineas.push('══════════════════════════════════════════════════════');
    return lineas.join('\n');
}
async function main() {
    console.log('\nIniciando validación del modelo LSTM...\n');
    const sucursales = await prisma.sucursales.findMany({
        where: { estado: { not: false } },
        orderBy: { id_sucursal: 'asc' },
    });
    if (sucursales.length === 0) {
        console.log('No se encontraron sucursales activas.');
        await prisma.$disconnect();
        return;
    }
    const resultados = [];
    for (const suc of sucursales) {
        const res = await validarSucursal(suc.id_sucursal, suc.nom_sucursal);
        resultados.push(res);
    }
    const reporte = generarReporte(resultados);
    console.log('\n' + reporte);
    const docsDir = path.join(__dirname, '..', 'docs');
    if (!fs.existsSync(docsDir))
        fs.mkdirSync(docsDir, { recursive: true });
    const fechaArchivo = new Date().toISOString().slice(0, 10);
    const rutaArchivo = path.join(docsDir, `validacion-modelo-${fechaArchivo}.txt`);
    fs.writeFileSync(rutaArchivo, reporte, 'utf-8');
    console.log(`\nReporte guardado en: docs/validacion-modelo-${fechaArchivo}.txt\n`);
    await prisma.$disconnect();
}
main().catch((e) => {
    console.error(e);
    prisma.$disconnect();
    process.exit(1);
});
//# sourceMappingURL=validar-modelo.js.map