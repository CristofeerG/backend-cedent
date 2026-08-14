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
const FACTOR_AMORTIGUACION = 0.9;
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
function aplicarDamping(forecastNorm, promSmooth) {
    return forecastNorm.map((v, i) => {
        const clamped = Math.min(Math.max(v, 0), 1.2);
        const peso = Math.pow(FACTOR_AMORTIGUACION, i);
        return clamped * peso + promSmooth * (1 - peso);
    });
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
        const promSmooth = trainSmooth.reduce((a, b) => a + b, 0) / trainSmooth.length;
        let m1Mae = 0, m1Rmse = 0, m1Dir = 0, m1Err = 0;
        let m2Mae = null, m2Rmse = null;
        const horizonte30 = Math.min(30, serie.length - MIN_PUNTOS_VALIDACION);
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
            m1Err = resultado.error ?? 0;
            const forecastNorm1 = red.forecast(trainSmooth, valLen);
            const forecastDamped1 = aplicarDamping(forecastNorm1, promSmooth);
            const forecastActual1 = forecastDamped1.map((v) => Math.max(0, v * trainMax));
            m1Mae = mae(valActual, forecastActual1);
            m1Rmse = rmse(valActual, forecastActual1);
            m1Dir = precisionDireccional(valActual, forecastActual1);
        }
        catch {
            omitidos++;
            continue;
        }
        if (horizonte30 >= 2) {
            const splitIdx2 = serie.length - horizonte30;
            const trainSerie2 = serie.slice(0, splitIdx2);
            const valActual2 = serie.slice(splitIdx2);
            const trainMax2 = Math.max(...trainSerie2);
            if (trainMax2 > 0) {
                const trainNorm2 = trainSerie2.map((v) => v / trainMax2);
                const trainSmooth2 = suavizarSerie(trainNorm2);
                const promSmooth2 = trainSmooth2.reduce((a, b) => a + b, 0) / trainSmooth2.length;
                try {
                    const red2 = new brain.recurrent.LSTMTimeStep({
                        inputSize: 1,
                        hiddenLayers: [10, 5],
                        outputSize: 1,
                    });
                    red2.train([trainSmooth2], {
                        iterations: ITERACIONES,
                        errorThresh: UMBRAL_ERROR,
                        log: false,
                    });
                    const forecastNorm2 = red2.forecast(trainSmooth2, horizonte30);
                    const forecastDamped2 = aplicarDamping(forecastNorm2, promSmooth2);
                    const forecastActual2 = forecastDamped2.map((v) => Math.max(0, v * trainMax2));
                    m2Mae = mae(valActual2, forecastActual2);
                    m2Rmse = rmse(valActual2, forecastActual2);
                }
                catch {
                }
            }
        }
        validados.push({
            nombre: nombreProducto.get(idProducto) ?? `prod_${idProducto}`,
            mae: m1Mae,
            rmse: m1Rmse,
            dirAcc: m1Dir,
            horizonteM1: valLen,
            mae30: m2Mae,
            rmse30: m2Rmse,
            horizonte30,
            errorEntrenamiento: m1Err,
            puntosHistoricos: serie.length,
        });
    }
    return { nombre: nomSucursal, validados, omitidos };
}
function fmt(n, dec) {
    return n.toFixed(dec).padStart(7);
}
function generarReporte(resultados) {
    const L = [];
    L.push('══════════════════════════════════════════════════════════');
    L.push('  VALIDACIÓN DEL MODELO LSTM — SISTEMA CENDENT');
    L.push('  (clamp [0, 1.2] + damped trend factor=0.9)');
    L.push('══════════════════════════════════════════════════════════');
    L.push('');
    let totValidados = 0;
    let sumMae1 = 0, sumRmse1 = 0, sumDir = 0;
    let totValidados30 = 0;
    let sumMae30 = 0, sumRmse30 = 0;
    for (const r of resultados) {
        const n = r.validados.length;
        const v30 = r.validados.filter((p) => p.mae30 !== null);
        const n30 = v30.length;
        const avgMae1 = n > 0 ? r.validados.reduce((a, p) => a + p.mae, 0) / n : 0;
        const avgRmse1 = n > 0 ? r.validados.reduce((a, p) => a + p.rmse, 0) / n : 0;
        const avgDir = n > 0 ? r.validados.reduce((a, p) => a + p.dirAcc, 0) / n : 0;
        const avgErr = n > 0 ? r.validados.reduce((a, p) => a + p.errorEntrenamiento, 0) / n : 0;
        const avgHor1 = n > 0 ? Math.round(r.validados.reduce((a, p) => a + p.horizonteM1, 0) / n) : 0;
        const avgMae30 = n30 > 0 ? v30.reduce((a, p) => a + (p.mae30 ?? 0), 0) / n30 : null;
        const avgRmse30 = n30 > 0 ? v30.reduce((a, p) => a + (p.rmse30 ?? 0), 0) / n30 : null;
        const avgHor30 = n30 > 0 ? Math.round(v30.reduce((a, p) => a + p.horizonte30, 0) / n30) : 0;
        L.push(`  Sucursal: ${r.nombre}`);
        L.push('  ──────────────────────────────────────────────────────');
        L.push(`  Productos validados             : ${String(n).padStart(4)}`);
        L.push(`  Productos omitidos (< ${MIN_PUNTOS_VALIDACION}d)      : ${String(r.omitidos).padStart(4)}`);
        L.push('');
        L.push(`  ── Métrica 1: horizonte dinámico (split 80/20) ──`);
        L.push(`  Horizonte promedio              : ${String(avgHor1).padStart(4)} d`);
        L.push(`  MAE promedio                    :${fmt(avgMae1, 2)} u/día`);
        L.push(`  RMSE promedio                   :${fmt(avgRmse1, 2)} u/día`);
        L.push(`  Precisión direccional           :${fmt(avgDir, 1)} %`);
        L.push(`  Error de entrenamiento avg      :${fmt(avgErr, 4)}`);
        L.push('');
        if (n30 > 0 && avgMae30 !== null && avgRmse30 !== null) {
            L.push(`  ── Métrica 2: horizonte 30 d (o máximo posible) ─`);
            L.push(`  Productos con métrica 30d       : ${String(n30).padStart(4)}`);
            L.push(`  Horizonte promedio              : ${String(avgHor30).padStart(4)} d`);
            L.push(`  MAE (30d) promedio              :${fmt(avgMae30, 2)} u/día`);
            L.push(`  RMSE (30d) promedio             :${fmt(avgRmse30, 2)} u/día`);
        }
        else {
            L.push(`  ── Métrica 2: horizonte 30 d ─────────────────────`);
            L.push(`  Series insuficientes para métrica 30d (necesita ≥ ${MIN_PUNTOS_VALIDACION + 2} puntos)`);
        }
        L.push('');
        totValidados += n;
        sumMae1 += avgMae1 * n;
        sumRmse1 += avgRmse1 * n;
        sumDir += avgDir * n;
        totValidados30 += n30;
        sumMae30 += (avgMae30 ?? 0) * n30;
        sumRmse30 += (avgRmse30 ?? 0) * n30;
    }
    const gMae1 = totValidados > 0 ? sumMae1 / totValidados : 0;
    const gRmse1 = totValidados > 0 ? sumRmse1 / totValidados : 0;
    const gDir = totValidados > 0 ? sumDir / totValidados : 0;
    const gMae30 = totValidados30 > 0 ? sumMae30 / totValidados30 : null;
    const gRmse30 = totValidados30 > 0 ? sumRmse30 / totValidados30 : null;
    L.push('──────────────────────────────────────────────────────────');
    L.push('  RESUMEN GLOBAL');
    L.push('──────────────────────────────────────────────────────────');
    L.push(`  Total productos validados       : ${String(totValidados).padStart(4)}`);
    L.push('');
    L.push('  ── Métrica 1 (horizonte dinámico) ────────────────');
    L.push(`  MAE global                      :${fmt(gMae1, 2)} u/día`);
    L.push(`  RMSE global                     :${fmt(gRmse1, 2)} u/día`);
    L.push(`  Precisión direccional           :${fmt(gDir, 1)} %`);
    L.push('');
    if (gMae30 !== null && gRmse30 !== null) {
        L.push('  ── Métrica 2 (horizonte 30 días) ─────────────────');
        L.push(`  Productos con métrica 30d       : ${String(totValidados30).padStart(4)}`);
        L.push(`  MAE global (30d)                :${fmt(gMae30, 2)} u/día`);
        L.push(`  RMSE global (30d)               :${fmt(gRmse30, 2)} u/día`);
    }
    else {
        L.push('  ── Métrica 2 (horizonte 30 días) ─────────────────');
        L.push('  Sin suficientes datos para métrica 30d');
    }
    L.push('══════════════════════════════════════════════════════════');
    L.push(`  Generado: ${new Date().toLocaleString('es-VE', { timeZone: 'America/Caracas' })}`);
    L.push('══════════════════════════════════════════════════════════');
    return L.join('\n');
}
async function main() {
    console.log('\nIniciando validación del modelo LSTM (con damping)...\n');
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