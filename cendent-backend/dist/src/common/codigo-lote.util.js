"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.generarCodigoLote = generarCodigoLote;
function generarCodigoLote(subcategoria, idProducto) {
    const prefijo = (subcategoria ?? '').padEnd(4, 'X').slice(0, 4).toUpperCase();
    const anio = new Date().getFullYear();
    return `${prefijo}-${anio}-${idProducto.toString().padStart(3, '0')}`;
}
//# sourceMappingURL=codigo-lote.util.js.map