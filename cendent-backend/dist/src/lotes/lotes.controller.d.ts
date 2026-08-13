import { ActualizarLoteDto } from './dto/actualizar-lote.dto';
import { CrearLoteDto } from './dto/crear-lote.dto';
import { LotesService } from './lotes.service';
export declare class LotesController {
    private readonly lotesService;
    constructor(lotesService: LotesService);
    registrarLote(dto: CrearLoteDto, req: any): Promise<{
        id_lote: number;
        id_producto: number | null;
        id_sucursal: number | null;
        codigo_lote: string | null;
        stock_actual: import("@prisma/client/runtime/library").Decimal;
        costo_unit: import("@prisma/client/runtime/library").Decimal | null;
        fecha_venc: Date;
        fecha_ingreso: Date | null;
    }>;
    obtenerPorProducto(idProducto: number, req: any): import(".prisma/client").Prisma.PrismaPromise<{
        id_lote: number;
        id_producto: number | null;
        id_sucursal: number | null;
        codigo_lote: string | null;
        stock_actual: import("@prisma/client/runtime/library").Decimal;
        costo_unit: import("@prisma/client/runtime/library").Decimal | null;
        fecha_venc: Date;
        fecha_ingreso: Date | null;
    }[]>;
    darDeBaja(id: number, req: any): Promise<{
        id_lote: number;
        id_producto: number | null;
        id_sucursal: number | null;
        codigo_lote: string | null;
        stock_actual: import("@prisma/client/runtime/library").Decimal;
        costo_unit: import("@prisma/client/runtime/library").Decimal | null;
        fecha_venc: Date;
        fecha_ingreso: Date | null;
    }>;
    actualizar(id: number, dto: ActualizarLoteDto): Promise<{
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
