"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const client_1 = require("@prisma/client");
const prisma = new client_1.PrismaClient();
async function main() {
    const movimientos = await prisma.movimientos.findMany({
        where: { tipo_mov: 'INGRESO_TRANSFERENCIA' },
        include: { lotes: true },
    });
    let migrados = 0;
    let existentes = 0;
    let saltados = 0;
    for (const movimiento of movimientos) {
        const lote = movimiento.lotes;
        if (!lote || !lote.codigo_lote) {
            saltados++;
            continue;
        }
        const partes = lote.codigo_lote.split('-');
        if (partes[0] !== 'REC') {
            saltados++;
            continue;
        }
        const idTransferencia = parseInt(partes[1], 10);
        if (isNaN(idTransferencia)) {
            saltados++;
            continue;
        }
        const existe = await prisma.detalle_transferencia.findFirst({
            where: {
                id_transferencia: idTransferencia,
                id_lote: movimiento.id_lote,
            },
        });
        if (existe) {
            existentes++;
            continue;
        }
        await prisma.detalle_transferencia.create({
            data: {
                id_transferencia: idTransferencia,
                id_lote: movimiento.id_lote,
                cantidad: movimiento.cantidad,
                rol: 'DESTINO',
            },
        });
        migrados++;
    }
    console.log('\n══════════════════════════════════════════════');
    console.log('  MIGRACIÓN detalle_transferencia completada');
    console.log('══════════════════════════════════════════════');
    console.log(`  Movimientos INGRESO_TRANSFERENCIA encontrados: ${movimientos.length}`);
    console.log(`  Vínculos creados (migrados)                 : ${migrados}`);
    console.log(`  Vínculos ya existentes (sin cambios)        : ${existentes}`);
    console.log(`  Movimientos saltados (código no REC-)       : ${saltados}`);
    console.log('══════════════════════════════════════════════\n');
}
main()
    .catch((e) => {
    console.error('Error en la migración:', e);
    process.exit(1);
})
    .finally(async () => {
    await prisma.$disconnect();
});
//# sourceMappingURL=migrar-detalle-transferencia.js.map