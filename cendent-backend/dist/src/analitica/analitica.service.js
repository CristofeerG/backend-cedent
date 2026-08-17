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
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
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
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
var AnaliticaService_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.AnaliticaService = void 0;
const common_1 = require("@nestjs/common");
const brain = __importStar(require("brain.js"));
const prisma_service_1 = require("../prisma/prisma.service");
const ITERACIONES = 500;
const UMBRAL_ERROR = 0.01;
const MIN_PUNTOS_SERIE = 14;
const HORIZONTE_DIAS = 30;
const FACTOR_AMORTIGUACION = 0.75;
const VENTANA_ACTIVIDAD_DIAS = 45;
const TIPOS_EGRESO = ['EGRESO_KIT', 'EGRESO_DIRECTO', 'SALIDA_TRANSFERENCIA'];
const SEMANAS_CONSUMO_REAL = 4;
let AnaliticaService = AnaliticaService_1 = class AnaliticaService {
    prisma;
    logger = new common_1.Logger(AnaliticaService_1.name);
    constructor(prisma) {
        this.prisma = prisma;
    }
    async obtenerEgresosPorSucursal(idSucursal) {
        return this.prisma.movimientos.findMany({
            where: {
                tipo_mov: { in: TIPOS_EGRESO },
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
    agruparConsumosPorFecha(egresos) {
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
            const mapaFecha = mapaConsumos.get(idProducto);
            mapaFecha.set(fecha, (mapaFecha.get(fecha) ?? 0) + cantidad);
        }
        return { mapaConsumos, nombreProducto };
    }
    suavizarSerie(serie) {
        return serie.map((_, i) => {
            const inicio = Math.max(0, i - 1);
            const fin = Math.min(serie.length - 1, i + 1);
            const ventana = serie.slice(inicio, fin + 1);
            return ventana.reduce((s, v) => s + v, 0) / ventana.length;
        });
    }
    crearYEntrenarLSTM(serieNormalizada) {
        const red = new brain.recurrent.LSTMTimeStep({
            inputSize: 1,
            hiddenLayers: [10, 5],
            outputSize: 1,
        });
        const serieSmooth = this.suavizarSerie(serieNormalizada);
        const resultado = red.train([serieSmooth], {
            iterations: ITERACIONES,
            errorThresh: UMBRAL_ERROR,
            log: false,
        });
        return { red, serieSmooth, errorEntrenamiento: resultado.error };
    }
    cederEventLoop() {
        return new Promise((resolve) => setImmediate(resolve));
    }
    async obtenerStockActual(idSucursal, idsProductos) {
        const hoy = new Date();
        hoy.setHours(0, 0, 0, 0);
        const lotes = await this.prisma.lotes.findMany({
            where: {
                id_sucursal: idSucursal,
                id_producto: { in: idsProductos },
                fecha_venc: { gte: hoy },
                stock_actual: { gt: 0 },
            },
            select: { id_producto: true, stock_actual: true },
        });
        const stockPorProducto = new Map();
        for (const lote of lotes) {
            if (lote.id_producto === null)
                continue;
            const acum = stockPorProducto.get(lote.id_producto) ?? 0;
            stockPorProducto.set(lote.id_producto, acum + Number(lote.stock_actual));
        }
        return stockPorProducto;
    }
    async obtenerConsumoReal(idSucursal) {
        const diasVentana = SEMANAS_CONSUMO_REAL * 7;
        const inicio = new Date();
        inicio.setHours(0, 0, 0, 0);
        inicio.setDate(inicio.getDate() - diasVentana);
        const egresos = await this.prisma.movimientos.findMany({
            where: {
                tipo_mov: { in: TIPOS_EGRESO },
                fecha_hora: { gte: inicio },
                lotes: { id_sucursal: idSucursal },
            },
            select: {
                cantidad: true,
                fecha_hora: true,
                lotes: { select: { id_producto: true } },
            },
        });
        const semanas = new Array(SEMANAS_CONSUMO_REAL).fill(0);
        const productosActivos = new Set();
        for (const mov of egresos) {
            if (!mov.fecha_hora)
                continue;
            const dias = (mov.fecha_hora.getTime() - inicio.getTime()) / 86_400_000;
            const semana = Math.floor(dias / 7);
            if (semana < 0 || semana >= SEMANAS_CONSUMO_REAL)
                continue;
            semanas[semana] += Number(mov.cantidad);
            if (mov.lotes?.id_producto != null) {
                productosActivos.add(mov.lotes.id_producto);
            }
        }
        const redondear = (v) => Math.round(v * 100) / 100;
        return {
            id_sucursal: idSucursal,
            dias_ventana: diasVentana,
            semanas: semanas.map(redondear),
            total: redondear(semanas.reduce((s, v) => s + v, 0)),
            productos_activos: Array.from(productosActivos).sort((a, b) => a - b),
        };
    }
    async prepararYEntrenar(idSucursal) {
        this.logger.log(`Iniciando entrenamiento LSTM para sucursal ${idSucursal}...`);
        const egresos = await this.obtenerEgresosPorSucursal(idSucursal);
        const { mapaConsumos, nombreProducto } = this.agruparConsumosPorFecha(egresos);
        const predicciones = [];
        for (const [idProducto, mapaFecha] of mapaConsumos.entries()) {
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
            const fechasOrdenadas = Array.from(mapaFecha.keys()).sort();
            const serie = fechasOrdenadas.map((f) => mapaFecha.get(f));
            if (serie.length < MIN_PUNTOS_SERIE)
                continue;
            const max = Math.max(...serie);
            if (max === 0)
                continue;
            const serieNorm = serie.map((v) => v / max);
            await this.cederEventLoop();
            const { red, serieSmooth, errorEntrenamiento } = this.crearYEntrenarLSTM(serieNorm);
            const prediccionNorm = red.run(serieSmooth);
            predicciones.push({
                id_producto: idProducto,
                nombre_producto: nombreProducto.get(idProducto) ?? `producto_${idProducto}`,
                puntos_historicos: serie.length,
                prediccion_siguiente: Math.round(prediccionNorm * max * 100) / 100,
                error_entrenamiento: Math.round(errorEntrenamiento * 10000) / 10000,
            });
        }
        this.logger.log(`Entrenamiento finalizado: ${predicciones.length} producto(s) para sucursal ${idSucursal}.`);
        return {
            id_sucursal: idSucursal,
            total_productos_entrenados: predicciones.length,
            iteraciones: ITERACIONES,
            predicciones,
        };
    }
    async generarPrediccion(idSucursal) {
        this.logger.log(`Generando predicción de demanda (${HORIZONTE_DIAS}d) para sucursal ${idSucursal}...`);
        const egresos = await this.obtenerEgresosPorSucursal(idSucursal);
        const { mapaConsumos, nombreProducto } = this.agruparConsumosPorFecha(egresos);
        const idsProductos = Array.from(mapaConsumos.keys());
        const stockPorProducto = await this.obtenerStockActual(idSucursal, idsProductos);
        const predicciones = [];
        for (const [idProducto, mapaFecha] of mapaConsumos.entries()) {
            const fechas = Array.from(mapaFecha.keys()).sort();
            const ultimaFechaConConsumo = fechas[fechas.length - 1];
            const diasInactividad = (Date.now() - new Date(ultimaFechaConConsumo).getTime()) / 86_400_000;
            if (diasInactividad > VENTANA_ACTIVIDAD_DIAS)
                continue;
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
            const fechasOrdenadas = Array.from(mapaFecha.keys()).sort();
            const serie = fechasOrdenadas.map((f) => mapaFecha.get(f));
            if (serie.length < MIN_PUNTOS_SERIE)
                continue;
            const max = Math.max(...serie);
            if (max === 0)
                continue;
            const serieNorm = serie.map((v) => v / max);
            await this.cederEventLoop();
            const { red, serieSmooth, errorEntrenamiento } = this.crearYEntrenarLSTM(serieNorm);
            const forecastNorm = red.forecast(serieSmooth, HORIZONTE_DIAS);
            const promSmooth = serieSmooth.reduce((a, b) => a + b, 0) / serieSmooth.length;
            const forecastDamped = forecastNorm.map((v, i) => {
                const clamped = Math.min(Math.max(v, 0), 1.2);
                const peso = Math.pow(FACTOR_AMORTIGUACION, i);
                return clamped * peso + promSmooth * (1 - peso);
            });
            const consumoPredicho30Dias = Math.round(forecastDamped.reduce((suma, v) => suma + v * max, 0) * 100) / 100;
            const prediccionSemanal = [0, 1, 2, 3].map((sem) => {
                const inicio = sem * 7;
                const fin = sem === 3 ? HORIZONTE_DIAS : inicio + 7;
                return (Math.round(forecastDamped
                    .slice(inicio, fin)
                    .reduce((s, v) => s + v * max, 0) * 100) / 100);
            });
            const stockTotal = stockPorProducto.get(idProducto) ?? 0;
            const promedioDiario = consumoPredicho30Dias / HORIZONTE_DIAS;
            const diasParaQuiebre = stockTotal === 0
                ? 0
                : promedioDiario > 0
                    ? Math.floor(stockTotal / promedioDiario)
                    : 9999;
            const sugerenciaCompra = Math.max(0, Math.round((consumoPredicho30Dias - stockTotal) * 100) / 100);
            predicciones.push({
                id_producto: idProducto,
                nombre_mat: nombreProducto.get(idProducto) ?? `producto_${idProducto}`,
                stock_total: Math.round(stockTotal * 100) / 100,
                consumo_predicho_30_dias: consumoPredicho30Dias,
                dias_para_quiebre: diasParaQuiebre,
                sugerencia_compra: sugerenciaCompra,
                prediccion_semanal: prediccionSemanal,
                error_entrenamiento: Math.round(errorEntrenamiento * 10000) / 10000,
            });
        }
        predicciones.sort((a, b) => a.dias_para_quiebre - b.dias_para_quiebre);
        this.logger.log(`Predicción finalizada: ${predicciones.length} producto(s) para sucursal ${idSucursal}.`);
        const errorPromedio = predicciones.length > 0
            ? Math.round((predicciones.reduce((s, p) => s + p.error_entrenamiento, 0) /
                predicciones.length) *
                10000) / 10000
            : 0;
        return {
            id_sucursal: idSucursal,
            total_productos_analizados: predicciones.length,
            error_entrenamiento_promedio: errorPromedio,
            predicciones,
        };
    }
    async generarYGuardar(idSucursal) {
        const resultado = await this.generarPrediccion(idSucursal);
        const registro = await this.prisma.predicciones_cache.upsert({
            where: { id_sucursal: idSucursal },
            create: { id_sucursal: idSucursal, resultado: resultado },
            update: { resultado: resultado },
        });
        return { ...resultado, generado_en: registro.generado_en };
    }
    async predecirDemanda(idSucursal) {
        const cached = await this.prisma.predicciones_cache.findUnique({
            where: { id_sucursal: idSucursal },
        });
        if (cached) {
            return { ...cached.resultado, generado_en: cached.generado_en };
        }
        setImmediate(() => {
            this.generarYGuardar(idSucursal).catch(e => this.logger.error(`Background training failed for sucursal ${idSucursal}: ${e.message}`));
        });
        return null;
    }
};
exports.AnaliticaService = AnaliticaService;
exports.AnaliticaService = AnaliticaService = AnaliticaService_1 = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [prisma_service_1.PrismaService])
], AnaliticaService);
//# sourceMappingURL=analitica.service.js.map