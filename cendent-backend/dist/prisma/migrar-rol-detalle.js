"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const client_1 = require("@prisma/client");
const prisma = new client_1.PrismaClient();
async function main() {
    await prisma.$executeRawUnsafe(`
    ALTER TABLE detalle_transferencia
    ADD COLUMN IF NOT EXISTS rol VARCHAR(10) NOT NULL DEFAULT 'ORIGEN'
  `);
    console.log('  Columna "rol" lista.');
    const marcadas = await prisma.$executeRawUnsafe(`
    UPDATE detalle_transferencia d
    SET rol = 'DESTINO'
    FROM lotes l, transferencias t
    WHERE d.id_lote = l.id_lote
      AND d.id_transferencia = t.id_transferencia
      AND t.id_sucursal_destino IS NOT NULL
      AND l.id_sucursal = t.id_sucursal_destino
      AND d.rol <> 'DESTINO'
  `);
    const resumen = await prisma.$queryRawUnsafe(`SELECT rol, COUNT(*) AS filas FROM detalle_transferencia GROUP BY rol ORDER BY rol`);
    const huerfanas = await prisma.$queryRawUnsafe(`SELECT COUNT(*) AS filas FROM detalle_transferencia WHERE id_lote IS NULL`);
    console.log('\n══════════════════════════════════════════════');
    console.log('  MIGRACIÓN detalle_transferencia.rol completada');
    console.log('══════════════════════════════════════════════');
    console.log(`  Filas marcadas como DESTINO en esta corrida : ${marcadas}`);
    for (const r of resumen) {
        console.log(`  Total con rol = ${r.rol.padEnd(7)}                  : ${r.filas}`);
    }
    console.log(`  Filas sin id_lote (quedan como ORIGEN)      : ${huerfanas[0].filas}`);
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
//# sourceMappingURL=migrar-rol-detalle.js.map