import { PrismaService } from '../prisma/prisma.service';
import { ActualizarProductoDto } from './dto/actualizar-producto.dto';
import { CrearProductoDto } from './dto/crear-producto.dto';
export declare class ProductosService {
    private readonly prisma;
    constructor(prisma: PrismaService);
    obtenerTodos(): import(".prisma/client").Prisma.PrismaPromise<{
        id_producto: number;
        nombre_mat: string;
        categoria: string | null;
        subcategoria: string | null;
        unidad_medida: string;
        stock_min: import("@prisma/client/runtime/library").Decimal | null;
    }[]>;
    buscarPorNombre(nombre: string): import(".prisma/client").Prisma.PrismaPromise<{
        id_producto: number;
        nombre_mat: string;
        categoria: string | null;
        subcategoria: string | null;
        unidad_medida: string;
        stock_min: import("@prisma/client/runtime/library").Decimal | null;
    }[]>;
    obtenerPorId(idProducto: number): Promise<{
        lotes: {
            id_lote: number;
            id_producto: number | null;
            codigo_lote: string | null;
            stock_actual: import("@prisma/client/runtime/library").Decimal;
            costo_unit: import("@prisma/client/runtime/library").Decimal | null;
            fecha_venc: Date;
            fecha_ingreso: Date | null;
            id_sucursal: number | null;
        }[];
    } & {
        id_producto: number;
        nombre_mat: string;
        categoria: string | null;
        subcategoria: string | null;
        unidad_medida: string;
        stock_min: import("@prisma/client/runtime/library").Decimal | null;
    }>;
    obtenerInventario(idSucursal?: number): Promise<{
        stock_total: number;
        id_producto: number;
        nombre_mat: string;
        categoria: string | null;
        subcategoria: string | null;
        unidad_medida: string;
        stock_min: import("@prisma/client/runtime/library").Decimal | null;
    }[]>;
    crear(dto: CrearProductoDto, idSucursal: number): Promise<({
        lotes: {
            id_lote: number;
            id_producto: number | null;
            codigo_lote: string | null;
            stock_actual: import("@prisma/client/runtime/library").Decimal;
            costo_unit: import("@prisma/client/runtime/library").Decimal | null;
            fecha_venc: Date;
            fecha_ingreso: Date | null;
            id_sucursal: number | null;
        }[];
    } & {
        id_producto: number;
        nombre_mat: string;
        categoria: string | null;
        subcategoria: string | null;
        unidad_medida: string;
        stock_min: import("@prisma/client/runtime/library").Decimal | null;
    }) | null>;
    actualizar(idProducto: number, dto: ActualizarProductoDto): Promise<{
        id_producto: number;
        nombre_mat: string;
        categoria: string | null;
        subcategoria: string | null;
        unidad_medida: string;
        stock_min: import("@prisma/client/runtime/library").Decimal | null;
    }>;
    eliminar(idProducto: number): Promise<{
        id_producto: number;
        nombre_mat: string;
        categoria: string | null;
        subcategoria: string | null;
        unidad_medida: string;
        stock_min: import("@prisma/client/runtime/library").Decimal | null;
    }>;
}
