// =============================================================================
//  prisma/migrar-detalle-transferencia.ts
//
//  Script de migración de datos históricos.
//  Vincula los movimientos INGRESO_TRANSFERENCIA existentes con sus registros
//  en detalle_transferencia, leyendo el id_transferencia del codigo_lote
//  (formato: REC-{id_transferencia}-{id_lote_original}).
//
//  Uso: npm run migrar:detalle
// =============================================================================

import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  // 1. Buscar todos los movimientos de tipo INGRESO_TRANSFERENCIA
  const movimientos = await prisma.movimientos.findMany({
    where: { tipo_mov: 'INGRESO_TRANSFERENCIA' },
    include: { lotes: true },
  });

  let migrados  = 0;
  let existentes = 0;
  let saltados  = 0;

  // 2. Procesar cada movimiento
  for (const movimiento of movimientos) {
    const lote = movimiento.lotes;

    // a. Validar que el lote exista y tenga el formato esperado
    if (!lote || !lote.codigo_lote) {
      saltados++;
      continue;
    }

    const partes = lote.codigo_lote.split('-');
    // Esperado: partes[0] = "REC", partes[1] = id_transferencia, partes[2] = id_lote_original
    if (partes[0] !== 'REC') {
      saltados++;
      continue;
    }

    const idTransferencia = parseInt(partes[1], 10);
    if (isNaN(idTransferencia)) {
      saltados++;
      continue;
    }

    // c. Verificar si ya existe el vínculo
    const existe = await prisma.detalle_transferencia.findFirst({
      where: {
        id_transferencia: idTransferencia,
        id_lote: movimiento.id_lote,
      },
    });

    if (existe) {
      // e. Ya estaba correcto — no crear duplicado
      existentes++;
      continue;
    }

    // d. Crear el vínculo faltante
    await prisma.detalle_transferencia.create({
      data: {
        id_transferencia: idTransferencia,
        id_lote: movimiento.id_lote,
        cantidad: movimiento.cantidad,
      },
    });
    migrados++;
  }

  // 4. Reporte final
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
