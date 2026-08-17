"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const client_1 = require("@prisma/client");
const prisma = new client_1.PrismaClient();
const TIPOS = {
    INGRESO_TRANSFERENCIA: 'DESTINO',
    SALIDA_TRANSFERENCIA: 'ORIGEN',
};
const TOLERANCIA_MS = 6 * 60 * 60 * 1000;
async function buscarPorSucursalYProducto(mov, tipo) {
    const idProducto = mov.lotes?.id_producto;
    const idSucursal = mov.lotes?.id_sucursal;
    const referencia = mov.fecha_hora?.getTime();
    if (idProducto == null || idSucursal == null || referencia == null)
        return null;
    const esIngreso = tipo === 'INGRESO_TRANSFERENCIA';
    const desde = new Date(referencia - TOLERANCIA_MS);
    const hasta = new Date(referencia + TOLERANCIA_MS);
    const candidatas = await prisma.transferencias.findMany({
        where: {
            ...(esIngreso ? { id_sucursal_destino: idSucursal } : { id_sucursal_origen: idSucursal }),
            OR: [
                { fecha_envio: { gte: desde, lte: hasta } },
                { fecha_recepcion: { gte: desde, lte: hasta } },
            ],
            detalle_transferencia: {
                some: {
                    cantidad: Number(mov.cantidad),
                    lotes: { id_producto: idProducto },
                },
            },
        },
    });
    const conDistancia = candidatas
        .map((t) => {
        const fecha = esIngreso ? (t.fecha_recepcion ?? t.fecha_envio) : t.fecha_envio;
        return {
            id_transferencia: t.id_transferencia,
            distancia: fecha ? Math.abs(referencia - fecha.getTime()) : Number.POSITIVE_INFINITY,
        };
    })
        .filter((c) => c.distancia <= TOLERANCIA_MS)
        .sort((a, b) => a.distancia - b.distancia);
    return conDistancia.length === 1 ? conDistancia[0] : null;
}
async function main() {
    await prisma.$executeRawUnsafe(`
    ALTER TABLE movimientos
    ADD COLUMN IF NOT EXISTS id_transferencia INTEGER
  `);
    await prisma.$executeRawUnsafe(`
    DO $$
    BEGIN
      IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'movimientos_id_transferencia_fkey'
      ) THEN
        ALTER TABLE movimientos
        ADD CONSTRAINT movimientos_id_transferencia_fkey
        FOREIGN KEY (id_transferencia) REFERENCES transferencias(id_transferencia);
      END IF;
    END $$;
  `);
    console.log('  Columna "id_transferencia" y clave foránea listas.\n');
    let inequivocos = 0;
    let porFechaCantidad = 0;
    let porSucursalProducto = 0;
    let sinResolver = 0;
    const tipos = Object.entries(TIPOS);
    for (const [tipo, rol] of tipos) {
        const movimientos = await prisma.movimientos.findMany({
            where: { tipo_mov: tipo, id_transferencia: null },
            orderBy: { id_movimiento: 'asc' },
            include: { lotes: { select: { id_producto: true, id_sucursal: true } } },
        });
        for (const mov of movimientos) {
            if (mov.id_lote == null) {
                sinResolver++;
                continue;
            }
            const candidatas = await prisma.detalle_transferencia.findMany({
                where: { id_lote: mov.id_lote, rol },
                include: { transferencias: true },
                distinct: ['id_transferencia'],
            });
            const validas = candidatas.filter((c) => c.transferencias != null);
            if (validas.length === 0) {
                const resuelta = await buscarPorSucursalYProducto(mov, tipo);
                if (resuelta == null) {
                    console.log(`  ! Movimiento ${mov.id_movimiento} (${tipo}, ${Number(mov.cantidad)} u, lote ${mov.id_lote}) sin rastro — se deja en NULL`);
                    sinResolver++;
                    continue;
                }
                await prisma.movimientos.update({
                    where: { id_movimiento: mov.id_movimiento },
                    data: { id_transferencia: resuelta.id_transferencia },
                });
                console.log(`  + Movimiento ${mov.id_movimiento} (${tipo}, ${Number(mov.cantidad)} u) → transferencia ${resuelta.id_transferencia} ` +
                    `por sucursal + producto (desfase ${Math.round(resuelta.distancia / 1000)} s)`);
                porSucursalProducto++;
                continue;
            }
            if (validas.length === 1) {
                await prisma.movimientos.update({
                    where: { id_movimiento: mov.id_movimiento },
                    data: { id_transferencia: validas[0].id_transferencia },
                });
                inequivocos++;
                continue;
            }
            const cantidadMov = Number(mov.cantidad);
            const referenciaMov = mov.fecha_hora?.getTime();
            const emparejadas = validas
                .filter((c) => Number(c.cantidad) === cantidadMov)
                .map((c) => {
                const t = c.transferencias;
                const fechaTrz = tipo === 'INGRESO_TRANSFERENCIA'
                    ? (t.fecha_recepcion ?? t.fecha_envio)
                    : t.fecha_envio;
                return {
                    id_transferencia: c.id_transferencia,
                    distancia: referenciaMov != null && fechaTrz != null
                        ? Math.abs(referenciaMov - fechaTrz.getTime())
                        : Number.POSITIVE_INFINITY,
                };
            })
                .filter((c) => c.distancia <= TOLERANCIA_MS)
                .sort((a, b) => a.distancia - b.distancia);
            if (emparejadas.length === 0) {
                console.log(`  ! Movimiento ${mov.id_movimiento} (${tipo}, ${cantidadMov} u, lote ${mov.id_lote}) sin candidata clara — se deja en NULL`);
                sinResolver++;
                continue;
            }
            const elegida = emparejadas[0];
            await prisma.movimientos.update({
                where: { id_movimiento: mov.id_movimiento },
                data: { id_transferencia: elegida.id_transferencia },
            });
            console.log(`  ~ Movimiento ${mov.id_movimiento} (${tipo}, ${cantidadMov} u) → transferencia ${elegida.id_transferencia} ` +
                `(${validas.length} candidatas, desfase ${Math.round(elegida.distancia / 1000)} s)`);
            porFechaCantidad++;
        }
    }
    const pendientes = await prisma.movimientos.count({
        where: { tipo_mov: { in: Object.keys(TIPOS) }, id_transferencia: null },
    });
    const conVinculo = await prisma.movimientos.count({
        where: { id_transferencia: { not: null } },
    });
    console.log('\n══════════════════════════════════════════════');
    console.log('  MIGRACIÓN movimientos.id_transferencia completada');
    console.log('══════════════════════════════════════════════');
    console.log(`  Resueltos sin ambigüedad (un solo candidato) : ${inequivocos}`);
    console.log(`  Resueltos por cantidad + fecha              : ${porFechaCantidad}`);
    console.log(`  Resueltos por sucursal + producto           : ${porSucursalProducto}`);
    console.log(`  Sin resolver (quedan en NULL)               : ${sinResolver}`);
    console.log(`  Movimientos con vínculo en total            : ${conVinculo}`);
    console.log(`  Movimientos de transferencia aún en NULL    : ${pendientes}`);
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
//# sourceMappingURL=migrar-transferencia-movimientos.js.map