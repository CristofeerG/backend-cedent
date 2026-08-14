import { EnviarTransferenciaDto } from './dto/enviar-transferencia.dto';
import { RecibirTransferenciaDto } from './dto/recibir-transferencia.dto';
import { TransferenciasService } from './transferencias.service';
export declare class TransferenciasController {
    private readonly transferenciasService;
    constructor(transferenciasService: TransferenciasService);
    obtenerTodas(req: any): import(".prisma/client").Prisma.PrismaPromise<({
        detalle_transferencia: ({
            lotes: ({
                productos: {
                    id_producto: number;
                    nombre_mat: string;
                    categoria: string | null;
                    subcategoria: string | null;
                    unidad_medida: string;
                    stock_min: import("@prisma/client/runtime/library").Decimal | null;
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
        } & {
            id_lote: number | null;
            cantidad: import("@prisma/client/runtime/library").Decimal;
            id_detalle: number;
            id_transferencia: number | null;
        })[];
        sucursales_transferencias_id_sucursal_destinoTosucursales: {
            id_sucursal: number;
            nom_sucursal: string;
            ubicacion: string | null;
            estado: boolean | null;
        } | null;
        sucursales_transferencias_id_sucursal_origenTosucursales: {
            id_sucursal: number;
            nom_sucursal: string;
            ubicacion: string | null;
            estado: boolean | null;
        } | null;
        usuarios_transferencias_id_usuario_enviaTousuarios: {
            nom_usuario: string;
        } | null;
        usuarios_transferencias_id_usuario_recibeTousuarios: {
            nom_usuario: string;
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
    })[]>;
    obtenerPorId(id: number): Promise<{
        detalle_transferencia: ({
            lotes: ({
                productos: {
                    id_producto: number;
                    nombre_mat: string;
                    categoria: string | null;
                    subcategoria: string | null;
                    unidad_medida: string;
                    stock_min: import("@prisma/client/runtime/library").Decimal | null;
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
        } & {
            id_lote: number | null;
            cantidad: import("@prisma/client/runtime/library").Decimal;
            id_detalle: number;
            id_transferencia: number | null;
        })[];
        sucursales_transferencias_id_sucursal_destinoTosucursales: {
            id_sucursal: number;
            nom_sucursal: string;
            ubicacion: string | null;
            estado: boolean | null;
        } | null;
        sucursales_transferencias_id_sucursal_origenTosucursales: {
            id_sucursal: number;
            nom_sucursal: string;
            ubicacion: string | null;
            estado: boolean | null;
        } | null;
        usuarios_transferencias_id_usuario_enviaTousuarios: {
            nom_usuario: string;
        } | null;
        usuarios_transferencias_id_usuario_recibeTousuarios: {
            nom_usuario: string;
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
    }>;
    enviarTransferencia(dto: EnviarTransferenciaDto, req: any): Promise<{
        estado: string | null;
        id_transferencia: number;
        id_usuario_envia: number | null;
        codigo_trz: string;
        fecha_envio: Date | null;
        fecha_recepcion: Date | null;
        id_sucursal_origen: number | null;
        id_sucursal_destino: number | null;
        id_usuario_recibe: number | null;
    }>;
    cancelarTransferencia(id: number): Promise<{
        estado: string | null;
        id_transferencia: number;
        id_usuario_envia: number | null;
        codigo_trz: string;
        fecha_envio: Date | null;
        fecha_recepcion: Date | null;
        id_sucursal_origen: number | null;
        id_sucursal_destino: number | null;
        id_usuario_recibe: number | null;
    }>;
    recibirTransferencia(dto: RecibirTransferenciaDto, req: any): Promise<{
        mensaje: string;
        codigo_trz: string;
        lotes_creados: {
            id_lote: number;
            id_producto: number | null;
            id_sucursal: number | null;
            codigo_lote: string | null;
            stock_actual: import("@prisma/client/runtime/library").Decimal;
            costo_unit: import("@prisma/client/runtime/library").Decimal | null;
            fecha_venc: Date;
            fecha_ingreso: Date | null;
        }[];
    }>;
}
