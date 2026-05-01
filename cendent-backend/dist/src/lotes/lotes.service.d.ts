import { PrismaService } from '../prisma/prisma.service';
import { CrearLoteDto } from './dto/crear-lote.dto';
export declare class LotesService {
    private readonly prisma;
    constructor(prisma: PrismaService);
    registrarLote(dto: CrearLoteDto, idSucursal: number): Promise<{
        id_lote: number;
        id_producto: number | null;
        codigo_lote: string | null;
        stock_actual: import("@prisma/client/runtime/library").Decimal;
        costo_unit: import("@prisma/client/runtime/library").Decimal | null;
        fecha_venc: Date;
        fecha_ingreso: Date | null;
        id_sucursal: number | null;
    }>;
    obtenerPorProducto(idProducto: number): import(".prisma/client").Prisma.PrismaPromise<{
        id_lote: number;
        id_producto: number | null;
        codigo_lote: string | null;
        stock_actual: import("@prisma/client/runtime/library").Decimal;
        costo_unit: import("@prisma/client/runtime/library").Decimal | null;
        fecha_venc: Date;
        fecha_ingreso: Date | null;
        id_sucursal: number | null;
    }[]>;
}
