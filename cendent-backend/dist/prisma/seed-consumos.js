"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const client_1 = require("@prisma/client");
const prisma = new client_1.PrismaClient();
function randInt(min, max) {
    return Math.floor(Math.random() * (max - min + 1)) + min;
}
function randFrom(arr) {
    return arr[Math.floor(Math.random() * arr.length)];
}
function randomTime(date) {
    const dt = new Date(date);
    dt.setHours(randInt(7, 17), randInt(0, 59), randInt(0, 59), 0);
    return dt;
}
const CONFIG_DIA = [
    { prob: 0.10, mult: 0.2 },
    { prob: 0.60, mult: 0.8 },
    { prob: 0.90, mult: 1.2 },
    { prob: 0.95, mult: 1.3 },
    { prob: 0.90, mult: 1.1 },
    { prob: 0.70, mult: 0.9 },
    { prob: 0.30, mult: 0.4 },
];
function multSemana(daysFromEnd) {
    const w = Math.floor(daysFromEnd / 7);
    if (w === 0)
        return 1.20;
    if (w === 1)
        return 1.15;
    if (w === 2)
        return 1.00;
    if (w === 3)
        return 0.85;
    if (w === 4)
        return 0.70;
    return 0.65;
}
async function main() {
    console.log('Cargando datos desde la BD...');
    const sucursales = await prisma.sucursales.findMany({
        where: { estado: true },
        select: { id_sucursal: true, nom_sucursal: true },
    });
    if (sucursales.length === 0) {
        console.log('Sin sucursales activas. Abortando.');
        return;
    }
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
    const kits = await prisma.kits.findMany({
        include: { detalle_kit: { where: { id_producto: { not: null } } } },
    });
    const kitsValidos = kits.filter(k => k.detalle_kit.length > 0);
    const usuario = await prisma.usuarios.findFirst({ select: { id_usuario: true } });
    if (!usuario) {
        console.log('Sin usuarios registrados. Abortando.');
        return;
    }
    const idUsuario = usuario.id_usuario;
    console.log(`  ${sucursales.length} sucursal(es) · ${lotes.length} lote(s) · ` +
        `${kitsValidos.length} kit(s) · usuario #${idUsuario}`);
    const stockMap = new Map();
    for (const l of lotes)
        stockMap.set(l.id_lote, Number(l.stock_actual));
    const lotesBySucursal = new Map();
    for (const l of lotes) {
        if (l.id_sucursal == null)
            continue;
        const arr = lotesBySucursal.get(l.id_sucursal) ?? [];
        arr.push(l);
        lotesBySucursal.set(l.id_sucursal, arr);
    }
    const hoy = new Date();
    hoy.setHours(23, 59, 59, 0);
    const inicio = new Date(hoy);
    inicio.setDate(inicio.getDate() - 70);
    inicio.setHours(0, 0, 0, 0);
    const diasTotal = Math.floor((hoy.getTime() - inicio.getTime()) / 86_400_000);
    console.log(`\nRango: ${inicio.toISOString().slice(0, 10)} → ${new Date().toISOString().slice(0, 10)} ` +
        `(${diasTotal} días / 10 semanas)`);
    const toInsert = [];
    const movsPorSucursal = new Map();
    const stockDescuentoSucursal = new Map();
    for (const s of sucursales) {
        movsPorSucursal.set(s.id_sucursal, 0);
        stockDescuentoSucursal.set(s.id_sucursal, 0);
    }
    for (const sucursal of sucursales) {
        const idSucursal = sucursal.id_sucursal;
        const lotesActivos = lotesBySucursal.get(idSucursal) ?? [];
        if (lotesActivos.length === 0) {
            console.log(`  [!] ${sucursal.nom_sucursal}: sin lotes con stock — se omite.`);
            continue;
        }
        for (let offset = 0; offset <= diasTotal; offset++) {
            const fechaDia = new Date(inicio);
            fechaDia.setDate(fechaDia.getDate() + offset);
            fechaDia.setHours(0, 0, 0, 0);
            const diaSemana = fechaDia.getDay();
            const cfg = CONFIG_DIA[diaSemana];
            if (Math.random() > cfg.prob)
                continue;
            const daysFromEnd = diasTotal - offset;
            const wMult = multSemana(daysFromEnd);
            const dMult = cfg.mult;
            const factorTotal = dMult * wMult;
            const baseDirectos = randInt(5, 12);
            const numDirectos = Math.max(1, Math.round(baseDirectos * factorTotal));
            const baseKits = kitsValidos.length > 0 ? randInt(0, 3) : 0;
            const numKits = Math.max(0, Math.round(baseKits * factorTotal));
            for (let k = 0; k < numKits; k++) {
                const kit = randFrom(kitsValidos);
                for (const detalle of kit.detalle_kit) {
                    const idProducto = detalle.id_producto;
                    const cantNecesaria = Number(detalle.cantidad_estandar);
                    const candidatos = lotesActivos
                        .filter(l => l.id_producto === idProducto && (stockMap.get(l.id_lote) ?? 0) > 0)
                        .sort((a, b) => (a.fecha_ingreso?.getTime() ?? 0) - (b.fecha_ingreso?.getTime() ?? 0));
                    if (candidatos.length === 0)
                        continue;
                    const lote = candidatos[0];
                    const stockActual = stockMap.get(lote.id_lote) ?? 0;
                    const cantidad = Math.min(cantNecesaria, stockActual);
                    if (cantidad <= 0)
                        continue;
                    stockMap.set(lote.id_lote, stockActual - cantidad);
                    stockDescuentoSucursal.set(idSucursal, (stockDescuentoSucursal.get(idSucursal) ?? 0) + cantidad);
                    toInsert.push({
                        id_usuario: idUsuario,
                        id_lote: lote.id_lote,
                        id_kit: kit.id_kit,
                        cantidad,
                        fecha_hora: randomTime(fechaDia),
                        tipo_mov: 'EGRESO_KIT',
                    });
                    movsPorSucursal.set(idSucursal, (movsPorSucursal.get(idSucursal) ?? 0) + 1);
                }
            }
            for (let d = 0; d < numDirectos; d++) {
                const disponibles = lotesActivos.filter(l => (stockMap.get(l.id_lote) ?? 0) > 0);
                if (disponibles.length === 0)
                    break;
                const lote = randFrom(disponibles);
                const stockActual = stockMap.get(lote.id_lote) ?? 0;
                const cantidad = Math.min(randInt(1, 5), stockActual);
                if (cantidad <= 0)
                    continue;
                stockMap.set(lote.id_lote, stockActual - cantidad);
                stockDescuentoSucursal.set(idSucursal, (stockDescuentoSucursal.get(idSucursal) ?? 0) + cantidad);
                toInsert.push({
                    id_usuario: idUsuario,
                    id_lote: lote.id_lote,
                    id_kit: null,
                    cantidad,
                    fecha_hora: randomTime(fechaDia),
                    tipo_mov: 'EGRESO_DIRECTO',
                });
                movsPorSucursal.set(idSucursal, (movsPorSucursal.get(idSucursal) ?? 0) + 1);
            }
        }
    }
    console.log('\nLimpiando movimientos anteriores (últimos 75 días)...');
    const deleted = await prisma.$executeRawUnsafe(`
    DELETE FROM movimientos
    WHERE tipo_mov IN ('EGRESO_KIT', 'EGRESO_DIRECTO')
      AND fecha_hora >= NOW() - INTERVAL '75 days'
  `);
    console.log(`  ${deleted} movimiento(s) eliminado(s).`);
    console.log(`\nInsertando ${toInsert.length} movimientos con patrón estacional...`);
    const BATCH = 500;
    let insertados = 0;
    for (let i = 0; i < toInsert.length; i += BATCH) {
        await prisma.movimientos.createMany({ data: toInsert.slice(i, i + BATCH) });
        insertados += Math.min(BATCH, toInsert.length - i);
        process.stdout.write(`\r  Insertados: ${insertados} / ${toInsert.length}`);
    }
    console.log();
    const lotesModificados = lotes.filter(l => Number(l.stock_actual) !== (stockMap.get(l.id_lote) ?? Number(l.stock_actual)));
    console.log(`Actualizando stock de ${lotesModificados.length} lote(s)...`);
    await Promise.all(lotesModificados.map(l => prisma.lotes.update({
        where: { id_lote: l.id_lote },
        data: { stock_actual: stockMap.get(l.id_lote) },
    })));
    const sep = '═'.repeat(56);
    console.log(`\n${sep}`);
    console.log('  Seed consumos estacional completado');
    console.log(sep);
    console.log(`  Total movimientos insertados : ${toInsert.length}`);
    console.log(`  Lotes con stock actualizado  : ${lotesModificados.length}`);
    console.log(`\n  Por sucursal:`);
    for (const s of sucursales) {
        const movs = movsPorSucursal.get(s.id_sucursal) ?? 0;
        const stock = stockDescuentoSucursal.get(s.id_sucursal) ?? 0;
        console.log(`    ${s.nom_sucursal.padEnd(28)} ${String(movs).padStart(5)} movimientos · ` +
            `${stock.toFixed(0).padStart(7)} u descontadas`);
    }
    console.log(sep);
}
main()
    .catch(e => { console.error(e); process.exit(1); })
    .finally(() => prisma.$disconnect());
//# sourceMappingURL=seed-consumos.js.map