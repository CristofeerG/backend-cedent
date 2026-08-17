// =============================================================================
//  prisma/migrar-rol-detalle.ts
//
//  Migración de esquema + datos: añade detalle_transferencia.rol y clasifica
//  las filas históricas.
//
//  Contexto: detalle_transferencia venía haciendo dos trabajos sin
//  distinguirlos. Al enviar se crea una fila por cada lote del que sale
//  mercadería (la guía de despacho); al recibir se crea otra apuntando al lote
//  de destino, para que el historial de movimientos pueda resolver de qué
//  sucursal vino un INGRESO_TRANSFERENCIA. Como nada las diferenciaba, una
//  transferencia recibida de 2 productos mostraba 4 líneas, cada producto
//  repetido con dos códigos de lote.
//
//  La clasificación de lo histórico es deducible sin ambigüedad: si el lote de
//  la fila pertenece a la sucursal destino de esa transferencia, la fila es el
//  comprobante de recepción; en cualquier otro caso es la línea de despacho.
//
//  Es idempotente: se puede correr las veces que haga falta.
//
//  Uso: npx ts-node --project tsconfig.seed.json prisma/migrar-rol-detalle.ts
// =============================================================================

import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  // 1. Columna. Se añade con DEFAULT 'ORIGEN' para que ninguna fila quede en
  //    NULL ni siquiera un instante; el paso 2 corrige las de destino.
  await prisma.$executeRawUnsafe(`
    ALTER TABLE detalle_transferencia
    ADD COLUMN IF NOT EXISTS rol VARCHAR(10) NOT NULL DEFAULT 'ORIGEN'
  `);
  console.log('  Columna "rol" lista.');

  // 2. Clasificar lo histórico.
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

  // 3. Reporte.
  const resumen = await prisma.$queryRawUnsafe<
    Array<{ rol: string; filas: bigint }>
  >(`SELECT rol, COUNT(*) AS filas FROM detalle_transferencia GROUP BY rol ORDER BY rol`);

  const huerfanas = await prisma.$queryRawUnsafe<Array<{ filas: bigint }>>(
    `SELECT COUNT(*) AS filas FROM detalle_transferencia WHERE id_lote IS NULL`,
  );

  console.log('\n══════════════════════════════════════════════');
  console.log('  MIGRACIÓN detalle_transferencia.rol completada');
  console.log('══════════════════════════════════════════════');
  console.log(`  Filas marcadas como DESTINO en esta corrida : ${marcadas}`);
  for (const r of resumen) {
    console.log(`  Total con rol = ${r.rol.padEnd(7)}                  : ${r.filas}`);
  }
  // Una fila sin lote no se puede clasificar por sucursal; queda como ORIGEN,
  // que es el valor seguro (se sigue mostrando en el detalle de la guía).
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
