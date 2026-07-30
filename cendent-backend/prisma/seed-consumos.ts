import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

// ─── Utilidades ───────────────────────────────────────────────────────────────

function randInt(min: number, max: number): number {
  return Math.floor(Math.random() * (max - min + 1)) + min;
}

function randFrom<T>(arr: T[]): T {
  return arr[Math.floor(Math.random() * arr.length)];
}

function randomTime(date: Date): Date {
  const dt = new Date(date);
  dt.setHours(randInt(8, 16), randInt(0, 59), randInt(0, 59), 0);
  return dt;
}

function isoWeek(d: Date): number {
  const utc = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()));
  utc.setUTCDate(utc.getUTCDate() + 4 - (utc.getUTCDay() || 7));
  const yearStart = new Date(Date.UTC(utc.getUTCFullYear(), 0, 1));
  return Math.ceil(((utc.getTime() - yearStart.getTime()) / 86_400_000 + 1) / 7);
}

// Devuelve 3-5 días laborables por semana dentro del rango [start, end]
function pickActiveDays(start: Date, end: Date): Date[] {
  const all: Date[] = [];
  const cur = new Date(start);
  while (cur <= end) {
    all.push(new Date(cur));
    cur.setDate(cur.getDate() + 1);
  }

  const byWeek = new Map<string, Date[]>();
  for (const d of all) {
    const key = `${d.getFullYear()}-W${String(isoWeek(d)).padStart(2, '0')}`;
    if (!byWeek.has(key)) byWeek.set(key, []);
    byWeek.get(key)!.push(d);
  }

  const active: Date[] = [];
  for (const days of byWeek.values()) {
    const workdays = days.filter(d => d.getDay() !== 0); // sin domingos
    const count = Math.min(randInt(3, 5), workdays.length);
    const shuffled = [...workdays].sort(() => Math.random() - 0.5);
    active.push(...shuffled.slice(0, count));
  }
  return active.sort((a, b) => a.getTime() - b.getTime());
}

// ─── Main ────────────────────────────────────────────────────────────────────

async function main() {
  console.log('Cargando datos desde la BD...');

  // 1. Sucursales activas
  const sucursales = await prisma.sucursales.findMany({
    where: { estado: true },
    select: { id_sucursal: true, nom_sucursal: true },
  });
  if (sucursales.length === 0) {
    console.log('Sin sucursales activas. Abortando.');
    return;
  }

  // 2. Lotes con stock disponible
  const lotes = await prisma.lotes.findMany({
    where: { stock_actual: { gt: 0 } },
    select: {
      id_lote: true,
      id_producto: true,
      id_sucursal: true,
      stock_actual: true,
      fecha_ingreso: true,
    },
  });

  // 3. Kits con detalle
  const kits = await prisma.kits.findMany({
    include: { detalle_kit: { where: { id_producto: { not: null } } } },
  });
  const kitsValidos = kits.filter(k => k.detalle_kit.length > 0);

  // 4. Cualquier usuario existente
  const usuario = await prisma.usuarios.findFirst({ select: { id_usuario: true } });
  if (!usuario) {
    console.log('Sin usuarios registrados. Abortando.');
    return;
  }
  const idUsuario = usuario.id_usuario;

  console.log(`  ${sucursales.length} sucursal(es) · ${lotes.length} lote(s) con stock · ${kitsValidos.length} kit(s) · usuario #${idUsuario}`);

  // ── Stock en memoria ───────────────────────────────────────────────────────
  const stockMap = new Map<number, number>();
  for (const l of lotes) stockMap.set(l.id_lote, Number(l.stock_actual));

  // Índice: id_sucursal → lotes de esa sucursal
  const lotesBySucursal = new Map<number, typeof lotes>();
  for (const l of lotes) {
    if (l.id_sucursal == null) continue;
    const arr = lotesBySucursal.get(l.id_sucursal) ?? [];
    arr.push(l);
    lotesBySucursal.set(l.id_sucursal, arr);
  }

  // ── Simulación ─────────────────────────────────────────────────────────────
  type MovRow = {
    id_usuario: number;
    id_lote: number;
    id_kit: number | null;
    cantidad: number;
    fecha_hora: Date;
    tipo_mov: string;
  };

  const toInsert: MovRow[] = [];
  const movsPorSucursal = new Map<number, number>();
  const stockPorSucursal = new Map<number, number>();
  for (const s of sucursales) {
    movsPorSucursal.set(s.id_sucursal, 0);
    stockPorSucursal.set(s.id_sucursal, 0);
  }

  const start = new Date('2026-06-01');
  const end   = new Date('2026-07-15');

  for (const sucursal of sucursales) {
    const idSucursal = sucursal.id_sucursal;
    const lotesActivos = lotesBySucursal.get(idSucursal) ?? [];
    if (lotesActivos.length === 0) {
      console.log(`  [!] ${sucursal.nom_sucursal}: sin lotes con stock — se omite.`);
      continue;
    }

    const activeDays = pickActiveDays(start, end);

    for (const day of activeDays) {
      const numMov = randInt(2, 6);

      for (let i = 0; i < numMov; i++) {
        const useKit = kitsValidos.length > 0 && Math.random() < 0.4;

        if (useKit) {
          // EGRESO_KIT — un movimiento por cada ítem del kit (FIFO por fecha_ingreso)
          const kit = randFrom(kitsValidos);

          for (const detalle of kit.detalle_kit) {
            const idProducto = detalle.id_producto!;
            const cantNecesaria = Number(detalle.cantidad_estandar);

            const candidatos = lotesActivos
              .filter(l => l.id_producto === idProducto && (stockMap.get(l.id_lote) ?? 0) > 0)
              .sort((a, b) => (a.fecha_ingreso?.getTime() ?? 0) - (b.fecha_ingreso?.getTime() ?? 0));

            if (candidatos.length === 0) continue;

            const lote = candidatos[0];
            const stockActual = stockMap.get(lote.id_lote) ?? 0;
            const cantidad = Math.min(cantNecesaria, stockActual);
            if (cantidad <= 0) continue;

            stockMap.set(lote.id_lote, stockActual - cantidad);
            toInsert.push({
              id_usuario: idUsuario,
              id_lote: lote.id_lote,
              id_kit: kit.id_kit,
              cantidad,
              fecha_hora: randomTime(day),
              tipo_mov: 'EGRESO_KIT',
            });
            movsPorSucursal.set(idSucursal, (movsPorSucursal.get(idSucursal) ?? 0) + 1);
            stockPorSucursal.set(idSucursal, (stockPorSucursal.get(idSucursal) ?? 0) + cantidad);
          }
        } else {
          // EGRESO_DIRECTO — lote aleatorio con stock > 0
          const disponibles = lotesActivos.filter(l => (stockMap.get(l.id_lote) ?? 0) > 0);
          if (disponibles.length === 0) continue;

          const lote = randFrom(disponibles);
          const stockActual = stockMap.get(lote.id_lote) ?? 0;
          const cantidad = Math.min(randInt(1, 5), stockActual);
          if (cantidad <= 0) continue;

          stockMap.set(lote.id_lote, stockActual - cantidad);
          toInsert.push({
            id_usuario: idUsuario,
            id_lote: lote.id_lote,
            id_kit: null,
            cantidad,
            fecha_hora: randomTime(day),
            tipo_mov: 'EGRESO_DIRECTO',
          });
          movsPorSucursal.set(idSucursal, (movsPorSucursal.get(idSucursal) ?? 0) + 1);
          stockPorSucursal.set(idSucursal, (stockPorSucursal.get(idSucursal) ?? 0) + cantidad);
        }
      }
    }
  }

  // ── Limpiar seed anterior (2025) ─────────────────────────────────────────
  console.log('\nLimpiando movimientos del seed anterior (2025-06-01 – 2025-07-15)...');
  const deleted = await prisma.$executeRawUnsafe(`
    DELETE FROM movimientos
    WHERE fecha_hora BETWEEN '2025-06-01' AND '2025-07-16'
      AND tipo_mov IN ('EGRESO_DIRECTO', 'EGRESO_KIT')
  `);
  console.log(`  ${deleted} movimiento(s) eliminado(s).`);

  // ── Persistir ──────────────────────────────────────────────────────────────
  console.log(`\nInsertando ${toInsert.length} movimientos...`);
  await prisma.movimientos.createMany({ data: toInsert });

  // Actualizar únicamente los lotes cuyo stock cambió
  const lotesModificados = lotes.filter(
    l => Number(l.stock_actual) !== (stockMap.get(l.id_lote) ?? Number(l.stock_actual)),
  );
  console.log(`Actualizando stock de ${lotesModificados.length} lote(s)...`);
  await Promise.all(
    lotesModificados.map(l =>
      prisma.lotes.update({
        where: { id_lote: l.id_lote },
        data: { stock_actual: stockMap.get(l.id_lote) },
      }),
    ),
  );

  // ── Resumen ────────────────────────────────────────────────────────────────
  const sep = '═'.repeat(52);
  console.log(`\n${sep}`);
  console.log('  Seed consumos completado');
  console.log(sep);
  console.log(`  Total movimientos insertados : ${toInsert.length}`);
  console.log(`  Lotes con stock actualizado  : ${lotesModificados.length}`);
  console.log(`\n  Por sucursal:`);
  for (const s of sucursales) {
    const movs  = movsPorSucursal.get(s.id_sucursal) ?? 0;
    const stock = stockPorSucursal.get(s.id_sucursal) ?? 0;
    console.log(`    ${s.nom_sucursal.padEnd(28)} ${String(movs).padStart(4)} movimientos · ${stock.toFixed(0).padStart(6)} u descontadas`);
  }
  console.log(sep);
}

main()
  .catch(e => { console.error(e); process.exit(1); })
  .finally(() => prisma.$disconnect());
