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
const prisma = new client_1.PrismaClient();
const ITERACIONES = 500;
const UMBRAL_ERROR = 0.01;
const MIN_PUNTOS_SERIE = 14;
const HORIZONTE_DIAS = 30;
const FACTOR_AMORTIGUACION = 0.75;
const VENTANA_ACTIVIDAD_DIAS = 45;
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
function agruparPorFecha(egresos) {
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
            nombreProducto.set(idProducto, mov.lotes.productos?.nombre_mat ?? `producto_${idProducto}`);
        }
        const mf = mapaConsumos.get(idProducto);
        mf.set(fecha, (mf.get(fecha) ?? 0) + cantidad);
    }
    return { mapaConsumos, nombreProducto };
}
function suavizar(serie) {
    return serie.map((_, i) => {
        const inicio = Math.max(0, i - 1);
        const fin = Math.min(serie.length - 1, i + 1);
        const v = serie.slice(inicio, fin + 1);
        return v.reduce((s, x) => s + x, 0) / v.length;
    });
}
function entrenarLSTM(serieNorm) {
    const red = new brain.recurrent.LSTMTimeStep({
        inputSize: 1,
        hiddenLayers: [10, 5],
        outputSize: 1,
    });
    const smooth = suavizar(serieNorm);
    const resultado = red.train([smooth], { iterations: ITERACIONES, errorThresh: UMBRAL_ERROR, log: false });
    return { red, smooth, errorEntrenamiento: resultado.error };
}
async function obtenerStock(idSucursal, idsProductos) {
    const hoy = new Date();
    hoy.setHours(0, 0, 0, 0);
    const lotes = await prisma.lotes.findMany({
        where: {
            id_sucursal: idSucursal,
            id_producto: { in: idsProductos },
            fecha_venc: { gte: hoy },
            stock_actual: { gt: 0 },
        },
        select: { id_producto: true, stock_actual: true },
    });
    const mapa = new Map();
    for (const l of lotes) {
        if (l.id_producto === null)
            continue;
        mapa.set(l.id_producto, (mapa.get(l.id_producto) ?? 0) + Number(l.stock_actual));
    }
    return mapa;
}
function rellenarDias(mapaFecha) {
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
}
async function generarYGuardarSucursal(idSucursal, nomSucursal) {
    console.log(`\n[${nomSucursal}] Cargando egresos...`);
    const egresos = await obtenerEgresos(idSucursal);
    const { mapaConsumos, nombreProducto } = agruparPorFecha(egresos);
    const idsProductos = Array.from(mapaConsumos.keys());
    const stockMapa = await obtenerStock(idSucursal, idsProductos);
    const candidatos = [];
    for (const [idProducto, mapaFecha] of mapaConsumos.entries()) {
        rellenarDias(mapaFecha);
        const serie = Array.from(mapaFecha.keys()).sort().map(f => mapaFecha.get(f));
        if (serie.length >= MIN_PUNTOS_SERIE && Math.max(...serie) > 0) {
            candidatos.push(idProducto);
        }
    }
    console.log(`[${nomSucursal}] ${candidatos.length} producto(s) a entrenar (de ${idsProductos.length} con egresos)`);
    const predicciones = [];
    let procesados = 0;
    for (const idProducto of candidatos) {
        procesados++;
        const nombre = nombreProducto.get(idProducto) ?? `producto_${idProducto}`;
        process.stdout.write(`  [${procesados}/${candidatos.length}] ${nombre.slice(0, 50).padEnd(50)} ...`);
        try {
            const mapaFecha = mapaConsumos.get(idProducto);
            const fechasOrdenadas = Array.from(mapaFecha.keys()).sort();
            const ultimaFecha = fechasOrdenadas[fechasOrdenadas.length - 1];
            const diasInactividad = (Date.now() - new Date(ultimaFecha).getTime()) / 86_400_000;
            if (diasInactividad > VENTANA_ACTIVIDAD_DIAS) {
                process.stdout.write(` SKIP (inactivo ${Math.round(diasInactividad)}d)\n`);
                continue;
            }
            rellenarDias(mapaFecha);
            const serie = Array.from(mapaFecha.keys()).sort().map(f => mapaFecha.get(f));
            const max = Math.max(...serie);
            const serieNorm = serie.map(v => v / max);
            const { red, smooth, errorEntrenamiento } = entrenarLSTM(serieNorm);
            const forecastNorm = red.forecast(smooth, HORIZONTE_DIAS);
            const promSmooth = smooth.reduce((a, b) => a + b, 0) / smooth.length;
            const forecastDamped = forecastNorm.map((v, i) => {
                const clamped = Math.min(Math.max(v, 0), 1.2);
                const peso = Math.pow(FACTOR_AMORTIGUACION, i);
                return clamped * peso + promSmooth * (1 - peso);
            });
            const consumo30d = Math.round(forecastDamped.reduce((s, v) => s + v * max, 0) * 100) / 100;
            const prediccionSemanal = [0, 1, 2, 3].map((sem) => {
                const inicio = sem * 7;
                const fin = sem === 3 ? HORIZONTE_DIAS : inicio + 7;
                return (Math.round(forecastDamped.slice(inicio, fin).reduce((s, v) => s + v * max, 0) * 100) / 100);
            });
            const stockTotal = stockMapa.get(idProducto) ?? 0;
            const promDiario = consumo30d / HORIZONTE_DIAS;
            const diasQuiebre = stockTotal === 0 ? 0 : promDiario > 0 ? Math.floor(stockTotal / promDiario) : 9999;
            const sugerencia = Math.max(0, Math.round((consumo30d - stockTotal) * 100) / 100);
            predicciones.push({
                id_producto: idProducto,
                nombre_mat: nombre,
                stock_total: Math.round(stockTotal * 100) / 100,
                consumo_predicho_30_dias: consumo30d,
                dias_para_quiebre: diasQuiebre,
                sugerencia_compra: sugerencia,
                prediccion_semanal: prediccionSemanal,
                error_entrenamiento: Math.round(errorEntrenamiento * 10000) / 10000,
            });
            process.stdout.write(' OK\n');
        }
        catch (err) {
            process.stdout.write(` ERROR: ${err?.message ?? err}\n`);
        }
        const parcial = [...predicciones].sort((a, b) => a.dias_para_quiebre - b.dias_para_quiebre);
        const errorPromedio = parcial.length > 0
            ? Math.round((parcial.reduce((s, p) => s + p.error_entrenamiento, 0) /
                parcial.length) *
                10000) / 10000
            : 0;
        const resultado = {
            id_sucursal: idSucursal,
            total_productos_analizados: parcial.length,
            error_entrenamiento_promedio: errorPromedio,
            predicciones: parcial,
        };
        await prisma.predicciones_cache.upsert({
            where: { id_sucursal: idSucursal },
            create: { id_sucursal: idSucursal, resultado },
            update: { resultado },
        });
    }
    console.log(`[${nomSucursal}] Caché guardada (${predicciones.length} producto(s)).`);
    return predicciones.length;
}
async function main() {
    const sucursales = await prisma.sucursales.findMany({
        where: { estado: true },
        select: { id_sucursal: true, nom_sucursal: true },
        orderBy: { id_sucursal: 'asc' },
    });
    if (sucursales.length === 0) {
        console.log('Sin sucursales activas. Abortando.');
        return;
    }
    console.log(`Generando caché para ${sucursales.length} sucursal(es)...`);
    const t0 = Date.now();
    const resumen = [];
    for (const s of sucursales) {
        const productos = await generarYGuardarSucursal(s.id_sucursal, s.nom_sucursal);
        resumen.push({ nombre: s.nom_sucursal, productos });
    }
    const elapsed = ((Date.now() - t0) / 1000 / 60).toFixed(1);
    const sep = '═'.repeat(52);
    console.log(`\n${sep}`);
    console.log('  generar:cache completado');
    console.log(sep);
    console.log(`  Tiempo total: ${elapsed} min`);
    console.log('\n  Por sucursal:');
    for (const r of resumen) {
        console.log(`    ${r.nombre.padEnd(28)} ${String(r.productos).padStart(4)} producto(s) en caché`);
    }
    console.log(sep);
}
main()
    .catch(e => { console.error(e); process.exit(1); })
    .finally(() => prisma.$disconnect());
//# sourceMappingURL=generar-cache.js.map