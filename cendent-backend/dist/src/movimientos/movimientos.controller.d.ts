import { ConsumirProductoDto } from './dto/consumir-producto.dto';
import { DespacharKitDto } from './dto/despachar-kit.dto';
import { MovimientosService } from './movimientos.service';
export declare class MovimientosController {
    private readonly movimientosService;
    constructor(movimientosService: MovimientosService);
    obtenerTodos(idSucursal?: string): import(".prisma/client").Prisma.PrismaPromise<({
        kits: {
            id_kit: number;
            nombre_procedimiento: string;
        } | null;
        lotes: ({
            productos: {
                id_producto: number;
                nombre_mat: string;
                categoria: string | null;
                subcategoria: string | null;
                unidad_medida: string;
                stock_min: import("@prisma/client/runtime/library").Decimal | null;
            } | null;
            sucursales: {
                id_sucursal: number;
                nom_sucursal: string;
                ubicacion: string | null;
                estado: boolean | null;
            } | null;
        } & {
            id_lote: number;
            id_producto: number | null;
            id_sucursal: number | null;
            codigo_lote: string | null;
            stock_actual: import("@prisma/client/runtime/library").Decimal;
            costo_unit: import("@prisma/client/runtime/library").Decimal | null;
            fecha_venc: Date;
            fecha_ingreso: Date | null;
        }) | null;
        usuarios: {
            id_usuario: number;
            id_sucursal: number | null;
            nom_usuario: string;
            password_hash: string;
            rol: string;
        } | null;
    } & {
        cantidad: import("@prisma/client/runtime/library").Decimal;
        fecha_hora: Date | null;
        tipo_mov: string | null;
        id_movimiento: number;
        id_usuario: number | null;
        id_lote: number | null;
        id_kit: number | null;
    })[]>;
    despacharKit(dto: DespacharKitDto, req: any): Promise<{
        cantidad: import("@prisma/client/runtime/library").Decimal;
        fecha_hora: Date | null;
        tipo_mov: string | null;
        id_movimiento: number;
        id_usuario: number | null;
        id_lote: number | null;
        id_kit: number | null;
    }[]>;
    consumirProducto(dto: ConsumirProductoDto, req: any): Promise<{
        cantidad: import("@prisma/client/runtime/library").Decimal;
        fecha_hora: Date | null;
        tipo_mov: string | null;
        id_movimiento: number;
        id_usuario: number | null;
        id_lote: number | null;
        id_kit: number | null;
    }[]>;
}
