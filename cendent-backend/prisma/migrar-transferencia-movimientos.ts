// =============================================================================
//  prisma/migrar-transferencia-movimientos.ts
//
//  Migración de esquema + datos: añade movimientos.id_transferencia y lo
//  rellena para el histórico.
//
//  Contexto: un movimiento de transferencia no guardaba a qué transferencia
//  pertenecía. La pantalla de movimientos lo deducía dando un rodeo por el
//  lote (movimiento → lote → detalle_transferencia → transferencia), y ese
//  rodeo es ambiguo: al recibir se reutiliza el lote de destino si coinciden
//  producto y fecha de vencimiento, así que un mismo lote puede haber recibido
//  de varias transferencias distintas.
//
//  Estrategia de relleno, en dos pasadas:
//
//    1. Caso inequívoco — el lote del movimiento sólo aparece en una
//       transferencia (con el rol que corresponde al tipo de movimiento).
//       No hay nada que decidir.
//
//    2. Caso ambiguo — el lote aparece en varias. Se empareja por cantidad y
//       cercanía temporal: el movimiento se registra en la misma operación que
//       la transferencia, con segundos de diferencia. Se exige que la cantidad
//       coincida y se elige la transferencia cuya fecha esté más cerca, dentro
//       de una ventana de tolerancia. Si ninguna candidata cumple, la fila se
//       deja en NULL en vez de adivinar.
//
//    3. Caso sin rastro en el lote — el lote no aparece en ninguna
//       transferencia con el rol esperado. Ocurre con recepciones antiguas que
//       cayeron en un lote ya existente del destino: la migración anterior sólo
//       creaba el vínculo cuando el lote tenía el código `REC-…`, así que a los
//       lotes reutilizados nunca se les creó. Se busca entonces por el otro
//       lado: transferencias hacia (o desde) esa sucursal, del mismo producto,
//       misma cantidad y dentro de la ventana temporal.
//
//  Es idempotente: sólo toca movimientos con id_transferencia NULL.
//
//  Uso: npx run migrar:transferencia-movimientos
// =============================================================================

import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

/** Tipos de movimiento que nacen de una transferencia, con su rol asociado. */
const TIPOS = {
  INGRESO_TRANSFERENCIA: 'DESTINO',
  SALIDA_TRANSFERENCIA: 'ORIGEN',
} as const;

/**
 * Ventana máxima entre la fecha de la transferencia y la del movimiento.
 *
 * En los datos reales la diferencia es de segundos (ambos se escriben en la
 * misma transacción). Se deja holgado por si alguna recepción antigua tardó,
 * pero acotado para no emparejar con una transferencia de otro día.
 */
const TOLERANCIA_MS = 6 * 60 * 60 * 1000; // 6 horas

type MovimientoConLote = {
  id_movimiento: number;
  id_lote: number | null;
  cantidad: unknown;
  fecha_hora: Date | null;
  lotes: { id_producto: number | null; id_sucursal: number | null } | null;
};

/**
 * Resuelve un movimiento cuyo lote no aparece en ninguna transferencia.
 *
 * Busca por el lado contrario: transferencias que llegaron a (o salieron de) la
 * sucursal del lote, con una línea de despacho del mismo producto y la misma
 * cantidad, dentro de la ventana temporal. Devuelve `null` si no hay
 * exactamente una candidata: es preferible dejar el dato vacío a inventarlo.
 */
async function buscarPorSucursalYProducto(
  mov: MovimientoConLote,
  tipo: keyof typeof TIPOS,
): Promise<{ id_transferencia: number; distancia: number } | null> {
  const idProducto = mov.lotes?.id_producto;
  const idSucursal = mov.lotes?.id_sucursal;
  const referencia = mov.fecha_hora?.getTime();
  if (idProducto == null || idSucursal == null || referencia == null) return null;

  const esIngreso = tipo === 'INGRESO_TRANSFERENCIA';
  const desde = new Date(referencia - TOLERANCIA_MS);
  const hasta = new Date(referencia + TOLERANCIA_MS);

  const candidatas = await prisma.transferencias.findMany({
    where: {
      // Un ingreso llega a la sucursal del lote; una salida parte de ella.
      ...(esIngreso ? { id_sucursal_destino: idSucursal } : { id_sucursal_origen: idSucursal }),
      OR: [
        { fecha_envio: { gte: desde, lte: hasta } },
        { fecha_recepcion: { gte: desde, lte: hasta } },
      ],
      // Alguna línea de despacho del mismo producto y la misma cantidad.
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
  // 1. Columna + clave foránea.
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

  const tipos = Object.entries(TIPOS) as Array<[keyof typeof TIPOS, string]>;
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

      // Transferencias en las que participó este lote con el rol adecuado.
      const candidatas = await prisma.detalle_transferencia.findMany({
        where: { id_lote: mov.id_lote, rol },
        include: { transferencias: true },
        distinct: ['id_transferencia'],
      });

      const validas = candidatas.filter((c) => c.transferencias != null);

      // Pasada 3: el lote no deja rastro. Se busca por sucursal, producto,
      // cantidad y fecha.
      if (validas.length === 0) {
        const resuelta = await buscarPorSucursalYProducto(mov, tipo);
        if (resuelta == null) {
          console.log(
            `  ! Movimiento ${mov.id_movimiento} (${tipo}, ${Number(mov.cantidad)} u, lote ${mov.id_lote}) sin rastro — se deja en NULL`,
          );
          sinResolver++;
          continue;
        }
        await prisma.movimientos.update({
          where: { id_movimiento: mov.id_movimiento },
          data: { id_transferencia: resuelta.id_transferencia },
        });
        console.log(
          `  + Movimiento ${mov.id_movimiento} (${tipo}, ${Number(mov.cantidad)} u) → transferencia ${resuelta.id_transferencia} ` +
            `por sucursal + producto (desfase ${Math.round(resuelta.distancia / 1000)} s)`,
        );
        porSucursalProducto++;
        continue;
      }

      // Pasada 1: sin ambigüedad.
      if (validas.length === 1) {
        await prisma.movimientos.update({
          where: { id_movimiento: mov.id_movimiento },
          data: { id_transferencia: validas[0].id_transferencia },
        });
        inequivocos++;
        continue;
      }

      // Pasada 2: emparejar por cantidad y cercanía temporal.
      //
      // La referencia temporal es fecha_envio para una salida (el movimiento se
      // escribe junto con ella) y también fecha_envio para un ingreso cuando no
      // hay fecha_recepcion, aunque lo normal es que la recepción exista y sea
      // la comparación correcta.
      const cantidadMov = Number(mov.cantidad);
      const referenciaMov = mov.fecha_hora?.getTime();

      const emparejadas = validas
        .filter((c) => Number(c.cantidad) === cantidadMov)
        .map((c) => {
          const t = c.transferencias!;
          const fechaTrz =
            tipo === 'INGRESO_TRANSFERENCIA'
              ? (t.fecha_recepcion ?? t.fecha_envio)
              : t.fecha_envio;
          return {
            id_transferencia: c.id_transferencia,
            distancia:
              referenciaMov != null && fechaTrz != null
                ? Math.abs(referenciaMov - fechaTrz.getTime())
                : Number.POSITIVE_INFINITY,
          };
        })
        .filter((c) => c.distancia <= TOLERANCIA_MS)
        .sort((a, b) => a.distancia - b.distancia);

      if (emparejadas.length === 0) {
        // Ninguna candidata cuadra en cantidad y fecha: mejor NULL que un dato
        // inventado. La pantalla sigue teniendo el respaldo por lote.
        console.log(
          `  ! Movimiento ${mov.id_movimiento} (${tipo}, ${cantidadMov} u, lote ${mov.id_lote}) sin candidata clara — se deja en NULL`,
        );
        sinResolver++;
        continue;
      }

      const elegida = emparejadas[0];
      await prisma.movimientos.update({
        where: { id_movimiento: mov.id_movimiento },
        data: { id_transferencia: elegida.id_transferencia },
      });
      console.log(
        `  ~ Movimiento ${mov.id_movimiento} (${tipo}, ${cantidadMov} u) → transferencia ${elegida.id_transferencia} ` +
          `(${validas.length} candidatas, desfase ${Math.round(elegida.distancia / 1000)} s)`,
      );
      porFechaCantidad++;
    }
  }

  // Reporte.
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
