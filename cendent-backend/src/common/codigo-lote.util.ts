export function generarCodigoLote(
  subcategoria: string | null | undefined,
  idProducto: number,
): string {
  const prefijo = (subcategoria ?? '').padEnd(4, 'X').slice(0, 4).toUpperCase();
  const anio = new Date().getFullYear();
  return `${prefijo}-${anio}-${idProducto.toString().padStart(3, '0')}`;
}
