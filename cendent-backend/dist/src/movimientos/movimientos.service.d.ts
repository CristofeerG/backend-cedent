import { PrismaService } from '../prisma/prisma.service';
export declare class MovimientosService {
    private readonly prisma;
    constructor(prisma: PrismaService);
    obtenerTodos(idSucursal?: number): import(".prisma/client").Prisma.PrismaPromise<({
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
            codigo_lote: string | null;
            stock_actual: import("@prisma/client/runtime/library").Decimal;
            costo_unit: import("@prisma/client/runtime/library").Decimal | null;
            fecha_venc: Date;
            fecha_ingreso: Date | null;
            id_sucursal: number | null;
        }) | null;
        usuarios: {
            id_usuario: number;
            id_sucursal: number | null;
            nom_usuario: string;
            rol: string;
            password_hash: string;
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
    despacharKit(idKit: number, idUsuario: number, idSucursal: number): Promise<{
        cantidad: import("@prisma/client/runtime/library").Decimal;
        fecha_hora: Date | null;
        tipo_mov: string | null;
        id_movimiento: number;
        id_usuario: number | null;
        id_lote: number | null;
        id_kit: number | null;
    }[]>;
}
