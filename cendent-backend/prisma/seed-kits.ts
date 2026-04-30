import { PrismaClient } from '@prisma/client';
import csvParser = require('csv-parser');
import * as fs from 'fs';
import * as path from 'path';

const prisma = new PrismaClient();

interface FilaKit {
  PROCEDIMIENTO: string;
  NOMBRE_MATERIAL: string;
  CONSUMO: string;
}

async function leerCsv(rutaArchivo: string): Promise<FilaKit[]> {
  return new Promise((resolver, rechazar) => {
    const filas: FilaKit[] = [];
    fs.createReadStream(rutaArchivo)
      .pipe(csvParser())
      .on('data', (fila: FilaKit) => filas.push(fila))
      .on('end', () => resolver(filas))
      .on('error', rechazar);
  });
}

async function sembrarKits() {
  // Ruta al CSV en la raíz del proyecto (un nivel arriba de /prisma)
  const rutaCsv = path.join(__dirname, '..', 'kits.csv');

  console.log(`Leyendo CSV desde: ${rutaCsv}`);
  const filas = await leerCsv(rutaCsv);
  console.log(`Filas leídas: ${filas.length}`);

  // 1. Limpiar tablas en orden para respetar FKs
  console.log('\nLimpiando tablas detalle_kit y kits...');
  // Los movimientos pueden referenciar kits (id_kit), se nulifica antes de borrar
  await prisma.movimientos.updateMany({
    where: { id_kit: { not: null } },
    data: { id_kit: null },
  });
  await prisma.detalle_kit.deleteMany();
  await prisma.kits.deleteMany();
  console.log('Tablas limpiadas.');

  // 2. Agrupar filas por PROCEDIMIENTO
  const grupos = filas.reduce<Record<string, FilaKit[]>>((acumulador, fila) => {
    const procedimiento = fila.PROCEDIMIENTO?.trim();
    if (!procedimiento) return acumulador;
    if (!acumulador[procedimiento]) acumulador[procedimiento] = [];
    acumulador[procedimiento].push(fila);
    return acumulador;
  }, {});

  const procedimientos = Object.keys(grupos);
  console.log(`\nProcedimientos encontrados: ${procedimientos.length} (${procedimientos.join(', ')})`);

  let kitsInsertados = 0;
  let detallesInsertados = 0;
  let productosNoEncontrados = 0;

  // 3. Insertar cada kit con sus detalles
  for (const [nombreProcedimiento, items] of Object.entries(grupos)) {
    const nuevoKit = await prisma.kits.create({
      data: { nombre_procedimiento: nombreProcedimiento },
    });
    kitsInsertados++;
    console.log(`\n[Kit] "${nombreProcedimiento}" -> id_kit: ${nuevoKit.id_kit}`);

    // 4. Procesar cada material del kit
    for (const item of items) {
      const nombreMaterial = item.NOMBRE_MATERIAL?.trim();
      if (!nombreMaterial) continue;

      // Busca el producto por coincidencia exacta con nombre_mat
      const producto = await prisma.productos.findFirst({
        where: { nombre_mat: nombreMaterial },
      });

      if (!producto) {
        console.warn(`  [OMITIDO] Producto no encontrado: "${nombreMaterial}"`);
        productosNoEncontrados++;
        continue;
      }

      await prisma.detalle_kit.create({
        data: {
          id_kit: nuevoKit.id_kit,
          id_producto: producto.id_producto,
          cantidad_estandar: parseFloat(item.CONSUMO),
        },
      });

      detallesInsertados++;
      console.log(`  [OK] ${nombreMaterial} (id: ${producto.id_producto}) x${item.CONSUMO}`);
    }
  }

  console.log(`
Seed finalizado:
  - Kits insertados:     ${kitsInsertados}
  - Detalles insertados: ${detallesInsertados}
  - Productos omitidos:  ${productosNoEncontrados}
`);
}

sembrarKits()
  .catch((error) => {
    console.error('Error fatal en seed-kits:', error);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
