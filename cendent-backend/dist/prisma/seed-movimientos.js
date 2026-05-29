"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const client_1 = require("@prisma/client");
const prisma = new client_1.PrismaClient();
function randomInt(min, max) {
    return Math.floor(Math.random() * (max - min + 1)) + min;
}
function randomFloat(min, max) {
    return Math.random() * (max - min) + min;
}
function agregarDias(fecha, dias) {
    const d = new Date(fecha);
    d.setDate(d.getDate() + dias);
    return d;
}
function esDiaLaboral(fecha) {
    const dia = fecha.getDay();
    return dia !== 0 && dia !== 6;
}
function conHoraAleatoria(fecha) {
    const d = new Date(fecha);
    d.setHours(randomInt(7, 17), randomInt(0, 59), randomInt(0, 59), 0);
    return d;
}
function shuffle(arr) {
    const a = [...arr];
    for (let i = a.length - 1; i > 0; i--) {
        const j = randomInt(0, i);
        [a[i], a[j]] = [a[j], a[i]];
    }
    return a;
}
async function simularMovimientos() {
    console.log('=== SIMULACIÓN DE MOVIMIENTOS HISTÓRICOS ===\n');
    const hoy = new Date();
    hoy.setHours(0, 0, 0, 0);
    const inicio = new Date(hoy);
    inicio.setMonth(inicio.getMonth() - 5);
    inicio.setDate(1);
    const diasTotal = Math.floor((hoy.getTime() - inicio.getTime()) / 86400000);
    console.log(`Rango: ${inicio.toISOString().slice(0, 10)} → ${hoy.toISOString().slice(0, 10)} (${diasTotal} días)`);
    const sucursales = await prisma.sucursales.findMany();
    if (!sucursales.length) {
        console.error('Sin sucursales. Abortando.');
        return;
    }
    const kits = await prisma.kits.findMany({ include: { detalle_kit: true } });
    if (!kits.length) {
        console.error('Sin kits. Abortando.');
        return;
    }
    const todosUsuarios = await prisma.usuarios.findMany();
    if (!todosUsuarios.length) {
        console.error('Sin usuarios. Abortando.');
        return;
    }
    let totalInsertados = 0;
    for (const sucursal of sucursales) {
        console.log(`\n[Sucursal] "${sucursal.nom_sucursal}" (id: ${sucursal.id_sucursal})`);
        const lotes = await prisma.lotes.findMany({ where: { id_sucursal: sucursal.id_sucursal } });
        if (!lotes.length) {
            console.log('  Sin lotes. Saltando.');
            continue;
        }
        const lotesPorProducto = new Map();
        for (const lote of lotes) {
            if (lote.id_producto === null)
                continue;
            if (!lotesPorProducto.has(lote.id_producto))
                lotesPorProducto.set(lote.id_producto, []);
            lotesPorProducto.get(lote.id_producto).push(lote);
        }
        const idsProductosDisponibles = Array.from(lotesPorProducto.keys());
        const usuariosSucursal = await prisma.usuarios.findMany({ where: { id_sucursal: sucursal.id_sucursal } });
        const usuarios = usuariosSucursal.length ? usuariosSucursal : todosUsuarios;
        const kitsValidos = kits.filter((k) => k.detalle_kit.some((d) => d.id_producto !== null && lotesPorProducto.has(d.id_producto)));
        console.log(`  Lotes: ${lotes.length} | Productos con lote: ${idsProductosDisponibles.length} | ` +
            `Kits aplicables: ${kitsValidos.length} | Usuarios: ${usuarios.length}`);
        if (!kitsValidos.length && !idsProductosDisponibles.length) {
            console.log('  Sin datos aplicables. Saltando.');
            continue;
        }
        const inserts = [];
        for (let offset = 0; offset <= diasTotal; offset++) {
            const fechaDia = agregarDias(inicio, offset);
            if (!esDiaLaboral(fechaDia))
                continue;
            const semana = Math.floor(offset / 7);
            const esSemanaAlta = semana % 3 !== 0;
            const registrosDia = [];
            if (kitsValidos.length) {
                const cantKits = esSemanaAlta ? randomInt(3, 6) : randomInt(1, 3);
                for (let k = 0; k < cantKits; k++) {
                    const kit = kitsValidos[randomInt(0, kitsValidos.length - 1)];
                    const usuario = usuarios[randomInt(0, usuarios.length - 1)];
                    const fechaMov = conHoraAleatoria(fechaDia);
                    for (const detalle of kit.detalle_kit) {
                        if (detalle.id_producto === null)
                            continue;
                        const lotesProducto = lotesPorProducto.get(detalle.id_producto);
                        if (!lotesProducto?.length)
                            continue;
                        const cantBase = Number(detalle.cantidad_estandar);
                        const cantidad = Math.max(0.01, Math.round(cantBase * randomFloat(0.7, 1.3) * 100) / 100);
                        registrosDia.push({
                            id_usuario: usuario.id_usuario,
                            id_lote: lotesProducto[0].id_lote,
                            id_kit: kit.id_kit,
                            cantidad,
                            fecha_hora: fechaMov,
                            tipo_mov: 'EGRESO_KIT',
                        });
                    }
                }
            }
            if (idsProductosDisponibles.length) {
                const cantDirectos = esSemanaAlta ? randomInt(10, 18) : randomInt(5, 10);
                const productosDelDia = shuffle(idsProductosDisponibles).slice(0, cantDirectos);
                for (const idProducto of productosDelDia) {
                    const lotesProducto = lotesPorProducto.get(idProducto);
                    const lote = lotesProducto[randomInt(0, lotesProducto.length - 1)];
                    const usuario = usuarios[randomInt(0, usuarios.length - 1)];
                    const fechaMov = conHoraAleatoria(fechaDia);
                    const cantidad = Math.max(0.01, Math.round(randomFloat(0.5, 5) * 100) / 100);
                    registrosDia.push({
                        id_usuario: usuario.id_usuario,
                        id_lote: lote.id_lote,
                        id_kit: null,
                        cantidad,
                        fecha_hora: fechaMov,
                        tipo_mov: 'EGRESO_DIRECTO',
                    });
                }
            }
            if (idsProductosDisponibles.length) {
                while (registrosDia.length < 25) {
                    const idProducto = idsProductosDisponibles[randomInt(0, idsProductosDisponibles.length - 1)];
                    const lotesProducto = lotesPorProducto.get(idProducto);
                    const lote = lotesProducto[0];
                    const usuario = usuarios[randomInt(0, usuarios.length - 1)];
                    const fechaMov = conHoraAleatoria(fechaDia);
                    registrosDia.push({
                        id_usuario: usuario.id_usuario,
                        id_lote: lote.id_lote,
                        id_kit: null,
                        cantidad: Math.max(0.01, Math.round(randomFloat(0.5, 3) * 100) / 100),
                        fecha_hora: fechaMov,
                        tipo_mov: 'EGRESO_DIRECTO',
                    });
                }
            }
            inserts.push(...registrosDia);
        }
        const BATCH = 300;
        let insertadosSucursal = 0;
        for (let i = 0; i < inserts.length; i += BATCH) {
            await prisma.movimientos.createMany({ data: inserts.slice(i, i + BATCH) });
            insertadosSucursal += Math.min(BATCH, inserts.length - i);
            process.stdout.write(`\r  Insertados: ${insertadosSucursal} / ${inserts.length}`);
        }
        totalInsertados += insertadosSucursal;
        console.log(`\n  ✓ ${insertadosSucursal} movimientos insertados`);
    }
    const diasLaboralesAprox = Math.round(diasTotal * 5 / 7);
    console.log('\n=== SIMULACIÓN COMPLETADA ===');
    console.log(`Movimientos totales   : ${totalInsertados}`);
    console.log(`Días laborales aprox  : ${diasLaboralesAprox}`);
    console.log(`Promedio por día      : ~${Math.round(totalInsertados / diasLaboralesAprox)}`);
    console.log(`Rango de fechas       : ${inicio.toISOString().slice(0, 10)} → ${hoy.toISOString().slice(0, 10)}`);
}
simularMovimientos()
    .catch((err) => { console.error('\nError fatal:', err); process.exit(1); })
    .finally(() => prisma.$disconnect());
//# sourceMappingURL=seed-movimientos.js.map