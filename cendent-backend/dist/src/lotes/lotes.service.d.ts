import { PrismaService } from '../prisma/prisma.service';
import { ActualizarLoteDto } from './dto/actualizar-lote.dto';
import { CrearLoteDto } from './dto/crear-lote.dto';
export declare class LotesService {
    private readonly prisma;
    constructor(prisma: PrismaService);
    registrarLote(dto: CrearLoteDto, idSucursal: number): Promise<{
        id_lote: number;
        id_producto: number | null;
        id_sucursal: number | null;
        codigo_lote: string | null;
        stock_actual: import("@prisma/client/runtime/library").Decimal;
        costo_unit: import("@prisma/client/runtime/library").Decimal | null;
        fecha_venc: Date;
        fecha_ingreso: Date | null;
    }>;
    obtenerPorProducto(idProducto: number): import(".prisma/client").Prisma.PrismaPromise<{
        id_lote: number;
        id_producto: number | null;
        id_sucursal: number | null;
        codigo_lote: string | null;
        stock_actual: import("@prisma/client/runtime/library").Decimal;
        costo_unit: import("@prisma/client/runtime/library").Decimal | null;
        fecha_venc: Date;
        fecha_ingreso: Date | null;
    }[]>;
    darDeBaja(idLote: number, idSucursal: number): Promise<{
        id_lote: number;
        id_producto: number | null;
        id_sucursal: number | null;
        codigo_lote: string | null;
        stock_actual: import("@prisma/client/runtime/library").Decimal;
        costo_unit: import("@prisma/client/runtime/library").Decimal | null;
        fecha_venc: Date;
        fecha_ingreso: Date | null;
    }>;
    actualizar(idLote: number, dto: ActualizarLoteDto): Promise<{
        id_lote: number;
        id_producto: number | null;
        id_sucursal: number | null;
        codigo_lote: string | null;
        stock_actual: import("@prisma/client/runtime/library").Decimal;
        costo_unit: import("@prisma/client/runtime/library").Decimal | null;
        fecha_venc: Date;
        fecha_ingreso: Date | null;
    }>;
}
