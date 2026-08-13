import { ActualizarProductoDto } from './dto/actualizar-producto.dto';
import { CrearProductoDto } from './dto/crear-producto.dto';
import { ProductosService } from './productos.service';
export declare class ProductosController {
    private readonly productosService;
    constructor(productosService: ProductosService);
    obtenerInventario(req: any): Promise<{
        stock_total: number;
        lotes_proximos_vencer: number;
        lotes_count: number;
        proxima_venc: string | null;
        id_producto: number;
        nombre_mat: string;
        categoria: string | null;
        subcategoria: string | null;
        unidad_medida: string;
        stock_min: import("@prisma/client/runtime/library").Decimal | null;
    }[]>;
    buscarPorNombre(nombre: string): import(".prisma/client").Prisma.PrismaPromise<({
        lotes: {
            id_lote: number;
            id_producto: number | null;
            id_sucursal: number | null;
            codigo_lote: string | null;
            stock_actual: import("@prisma/client/runtime/library").Decimal;
            costo_unit: import("@prisma/client/runtime/library").Decimal | null;
            fecha_venc: Date;
            fecha_ingreso: Date | null;
        }[];
    } & {
        id_producto: number;
        nombre_mat: string;
        categoria: string | null;
        subcategoria: string | null;
        unidad_medida: string;
        stock_min: import("@prisma/client/runtime/library").Decimal | null;
    })[]>;
    obtenerTodos(): import(".prisma/client").Prisma.PrismaPromise<{
        id_producto: number;
        nombre_mat: string;
        categoria: string | null;
        subcategoria: string | null;
        unidad_medida: string;
        stock_min: import("@prisma/client/runtime/library").Decimal | null;
    }[]>;
    obtenerPorId(id: number): Promise<{
        lotes: {
            id_lote: number;
            id_producto: number | null;
            id_sucursal: number | null;
            codigo_lote: string | null;
            stock_actual: import("@prisma/client/runtime/library").Decimal;
            costo_unit: import("@prisma/client/runtime/library").Decimal | null;
            fecha_venc: Date;
            fecha_ingreso: Date | null;
        }[];
    } & {
        id_producto: number;
        nombre_mat: string;
        categoria: string | null;
        subcategoria: string | null;
        unidad_medida: string;
        stock_min: import("@prisma/client/runtime/library").Decimal | null;
    }>;
    crear(dto: CrearProductoDto, req: any): Promise<({
        lotes: {
            id_lote: number;
            id_producto: number | null;
            id_sucursal: number | null;
            codigo_lote: string | null;
            stock_actual: import("@prisma/client/runtime/library").Decimal;
            costo_unit: import("@prisma/client/runtime/library").Decimal | null;
            fecha_venc: Date;
            fecha_ingreso: Date | null;
        }[];
    } & {
        id_producto: number;
        nombre_mat: string;
        categoria: string | null;
        subcategoria: string | null;
        unidad_medida: string;
        stock_min: import("@prisma/client/runtime/library").Decimal | null;
    }) | null>;
    actualizar(id: number, dto: ActualizarProductoDto): Promise<{
        id_producto: number;
        nombre_mat: string;
        categoria: string | null;
        subcategoria: string | null;
        unidad_medida: string;
        stock_min: import("@prisma/client/runtime/library").Decimal | null;
    }>;
    eliminar(id: number): Promise<{
        id_producto: number;
        nombre_mat: string;
        categoria: string | null;
        subcategoria: string | null;
        unidad_medida: string;
        stock_min: import("@prisma/client/runtime/library").Decimal | null;
    }>;
}
