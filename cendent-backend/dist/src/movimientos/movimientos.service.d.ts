import { PrismaService } from '../prisma/prisma.service';
import { SustitucionDto } from './dto/despachar-kit.dto';
export declare class MovimientosService {
    private readonly prisma;
    constructor(prisma: PrismaService);
    obtenerTodos(idSucursal?: number, idProducto?: number): import(".prisma/client").Prisma.PrismaPromise<({
        kits: {
            id_kit: number;
            nombre_procedimiento: string;
        } | null;
        lotes: ({
            detalle_transferencia: ({
                transferencias: ({
                    sucursales_transferencias_id_sucursal_destinoTosucursales: {
                        nom_sucursal: string;
                    } | null;
                    sucursales_transferencias_id_sucursal_origenTosucursales: {
                        nom_sucursal: string;
                    } | null;
                } & {
                    estado: string | null;
                    id_transferencia: number;
                    id_usuario_envia: number | null;
                    codigo_trz: string;
                    fecha_envio: Date | null;
                    fecha_recepcion: Date | null;
                    id_sucursal_origen: number | null;
                    id_sucursal_destino: number | null;
                    id_usuario_recibe: number | null;
                }) | null;
            } & {
                id_lote: number | null;
                cantidad: import("@prisma/client/runtime/library").Decimal;
                id_detalle: number;
                id_transferencia: number | null;
            })[];
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
        id_movimiento: number;
        id_usuario: number | null;
        id_lote: number | null;
        id_kit: number | null;
        cantidad: import("@prisma/client/runtime/library").Decimal;
        fecha_hora: Date | null;
        tipo_mov: string | null;
    })[]>;
    despacharKit(idKit: number, idUsuario: number, idSucursal: number, sustituciones: SustitucionDto[]): Promise<{
        movimientos: {
            id_movimiento: number;
            id_usuario: number | null;
            id_lote: number | null;
            id_kit: number | null;
            cantidad: import("@prisma/client/runtime/library").Decimal;
            fecha_hora: Date | null;
            tipo_mov: string | null;
        }[];
        lotes_usados: {
            nombre_producto: string;
            num_lote: string | null;
            fecha_vencimiento: Date;
            stock_restante: number;
        }[];
    }>;
    consumirProducto(idProducto: number, cantidad: number, idUsuario: number, idSucursal: number): Promise<{
        movimientos: {
            id_movimiento: number;
            id_usuario: number | null;
            id_lote: number | null;
            id_kit: number | null;
            cantidad: import("@prisma/client/runtime/library").Decimal;
            fecha_hora: Date | null;
            tipo_mov: string | null;
        }[];
        lote_usado: {
            num_lote: string | null;
            fecha_vencimiento: Date;
            stock_restante: number;
        } | null;
    }>;
}
