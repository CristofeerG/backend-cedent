import { PrismaClient } from '@prisma/client';
import csvParser = require('csv-parser');
import * as fs from 'fs';
import * as path from 'path';

const prisma = new PrismaClient();

interface FilaInventario {
  NOMBRE_MATERIAL: string;
  CATEGORIA: string;
  SUBCATEGORIA: string;
  UNIDAD_MEDIDA: string;
  FACTOR_CONV: string;
  STOCK_ACTUAL: string;
  STOCK_MIN: string;
  FECHA_VENC: string;
  COSTO_UNIT: string;
}

const ID_SUCURSAL = 1;
const ID_USUARIO = 1;

async function leerCsv(rutaArchivo: string): Promise<FilaInventario[]> {
  return new Promise((resolver, rechazar) => {
    const filas: FilaInventario[] = [];
    fs.createReadStream(rutaArchivo)
      .pipe(csvParser())
      .on('data', (fila: FilaInventario) => filas.push(fila))
      .on('end', () => resolver(filas))
      .on('error', rechazar);
  });
}

function generarCodigoLote(subcategoria: string, anio: number, idProducto: number): string {
  const prefijo = subcategoria.trim().substring(0, 4).toUpperCase();
  const idFormateado = String(idProducto).padStart(3, '0');
  return `${prefijo}-${anio}-${idFormateado}`;
}

async function sembrar() {
  const rutaCsv = path.join(__dirname, 'inventario_hoja2.csv');
  const filas = await leerCsv(rutaCsv);
  const anioActual = new Date().getFullYear();

  let insertados = 0;
  let omitidos = 0;
  let errores = 0;

  console.log(`Iniciando seed con ${filas.length} registros del CSV...`);

  for (const fila of filas) {
    const nombreMat = fila.NOMBRE_MATERIAL?.trim();
    if (!nombreMat) continue;

    try {
      const factorConv = parseFloat(fila.FACTOR_CONV) || 1;
      const stockCsv = parseFloat(fila.STOCK_ACTUAL) || 0;
      const stockActual = stockCsv * factorConv;
      const costoUnit = parseFloat(fila.COSTO_UNIT) || 0;
      const stockMin = parseFloat(fila.STOCK_MIN) || 0;
      const fechaVenc: Date = fila.FECHA_VENC
        ? new Date(fila.FECHA_VENC)
        : new Date('2099-12-31');

      // Upsert: buscar producto existente por nombre para evitar duplicados
      const productoExistente = await prisma.productos.findFirst({
        where: { nombre_mat: nombreMat },
      });

      if (productoExistente) {
        omitidos++;
        continue;
      }

      const nuevoProducto = await prisma.productos.create({
        data: {
          nombre_mat: nombreMat,
          categoria: fila.CATEGORIA?.trim() || null,
          subcategoria: fila.SUBCATEGORIA?.trim() || null,
          unidad_medida: fila.UNIDAD_MEDIDA?.trim(),
          stock_min: stockMin,
        },
      });

      const idProducto = nuevoProducto.id_producto;
      const codigoLote = generarCodigoLote(fila.SUBCATEGORIA || '', anioActual, idProducto);

      const nuevoLote = await prisma.lotes.create({
        data: {
          id_producto: idProducto,
          id_sucursal: ID_SUCURSAL,
          codigo_lote: codigoLote,
          stock_actual: stockActual,
          costo_unit: costoUnit,
          fecha_venc: fechaVenc,
        },
      });

      await prisma.movimientos.create({
        data: {
          id_usuario: ID_USUARIO,
          id_lote: nuevoLote.id_lote,
          id_kit: null,
          cantidad: stockActual,
          tipo_mov: 'INGRESO_INICIAL',
        },
      });

      insertados++;
      console.log(`[OK] ${nombreMat} | Lote: ${codigoLote} | Stock: ${stockActual}`);
    } catch (error) {
      errores++;
      console.error(`[ERROR] Fila "${nombreMat}":`, error.message);
    }
  }

  console.log(`\nSeed finalizado: ${insertados} insertados, ${omitidos} omitidos (ya existían), ${errores} errores.`);
}

sembrar()
  .catch((error) => {
    console.error('Error fatal en el seed:', error);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
