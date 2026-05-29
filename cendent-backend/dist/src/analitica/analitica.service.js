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
const ITERACIONES = 100;
const UMBRAL_ERROR = 0.025;
const MIN_PUNTOS_SERIE = 3;
const HORIZONTE_DIAS = 30;
let AnaliticaService = AnaliticaService_1 = class AnaliticaService {
    prisma;
    logger = new common_1.Logger(AnaliticaService_1.name);
    constructor(prisma) {
        this.prisma = prisma;
    }
    async obtenerEgresosPorSucursal(idSucursal) {
        return this.prisma.movimientos.findMany({
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
    crearYEntrenarLSTM(serieNormalizada) {
        const red = new brain.recurrent.LSTMTimeStep({
            inputSize: 1,
            hiddenLayers: [10, 5],
            outputSize: 1,
        });
        const resultado = red.train([serieNormalizada], {
            iterations: ITERACIONES,
            errorThresh: UMBRAL_ERROR,
            log: false,
        });
        return { red, errorEntrenamiento: resultado.error };
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
    async prepararYEntrenar(idSucursal) {
        this.logger.log(`Iniciando entrenamiento LSTM para sucursal ${idSucursal}...`);
        const egresos = await this.obtenerEgresosPorSucursal(idSucursal);
        const { mapaConsumos, nombreProducto } = this.agruparConsumosPorFecha(egresos);
        const predicciones = [];
        for (const [idProducto, mapaFecha] of mapaConsumos.entries()) {
            const serie = Array.from(mapaFecha.values());
            if (serie.length < MIN_PUNTOS_SERIE)
                continue;
            const max = Math.max(...serie);
            if (max === 0)
                continue;
            const serieNorm = serie.map((v) => v / max);
            const { red, errorEntrenamiento } = this.crearYEntrenarLSTM(serieNorm);
            const prediccionNorm = red.run(serieNorm);
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
    async predecirDemanda(idSucursal) {
        this.logger.log(`Iniciando predicción de demanda (${HORIZONTE_DIAS}d) para sucursal ${idSucursal}...`);
        const egresos = await this.obtenerEgresosPorSucursal(idSucursal);
        const { mapaConsumos, nombreProducto } = this.agruparConsumosPorFecha(egresos);
        const idsProductos = Array.from(mapaConsumos.keys());
        const stockPorProducto = await this.obtenerStockActual(idSucursal, idsProductos);
        const predicciones = [];
        for (const [idProducto, mapaFecha] of mapaConsumos.entries()) {
            const serie = Array.from(mapaFecha.values());
            if (serie.length < MIN_PUNTOS_SERIE)
                continue;
            const max = Math.max(...serie);
            if (max === 0)
                continue;
            const serieNorm = serie.map((v) => v / max);
            const { red } = this.crearYEntrenarLSTM(serieNorm);
            const forecastNorm = red.forecast(serieNorm, HORIZONTE_DIAS);
            const consumoPredicho30Dias = Math.round(forecastNorm.reduce((suma, v) => suma + v * max, 0) * 100) / 100;
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
            });
        }
        predicciones.sort((a, b) => a.dias_para_quiebre - b.dias_para_quiebre);
        this.logger.log(`Predicción finalizada: ${predicciones.length} producto(s) analizados para sucursal ${idSucursal}.`);
        return {
            id_sucursal: idSucursal,
            total_productos_analizados: predicciones.length,
            predicciones,
        };
    }
};
exports.AnaliticaService = AnaliticaService;
exports.AnaliticaService = AnaliticaService = AnaliticaService_1 = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [prisma_service_1.PrismaService])
], AnaliticaService);
//# sourceMappingURL=analitica.service.js.map