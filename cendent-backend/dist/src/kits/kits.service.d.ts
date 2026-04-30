import { PrismaService } from '../prisma/prisma.service';
import { CrearKitDto } from './dto/crear-kit.dto';
export declare class KitsService {
    private readonly prisma;
    constructor(prisma: PrismaService);
    obtenerTodos(): import(".prisma/client").Prisma.PrismaPromise<({
        detalle_kit: ({
            productos: {
                id_producto: number;
                nombre_mat: string;
                categoria: string | null;
                subcategoria: string | null;
                unidad_medida: string;
                stock_min: import("@prisma/client/runtime/library").Decimal | null;
            } | null;
        } & {
            id_kit: number | null;
            id_producto: number | null;
            cantidad_estandar: import("@prisma/client/runtime/library").Decimal;
            id_detalle: number;
        })[];
    } & {
        id_kit: number;
        nombre_procedimiento: string;
    })[]>;
    obtenerPorId(idKit: number): Promise<{
        detalle_kit: ({
            productos: {
                id_producto: number;
                nombre_mat: string;
                categoria: string | null;
                subcategoria: string | null;
                unidad_medida: string;
                stock_min: import("@prisma/client/runtime/library").Decimal | null;
            } | null;
        } & {
            id_kit: number | null;
            id_producto: number | null;
            cantidad_estandar: import("@prisma/client/runtime/library").Decimal;
            id_detalle: number;
        })[];
    } & {
        id_kit: number;
        nombre_procedimiento: string;
    }>;
    crear(dto: CrearKitDto): Promise<({
        detalle_kit: ({
            productos: {
                id_producto: number;
                nombre_mat: string;
                categoria: string | null;
                subcategoria: string | null;
                unidad_medida: string;
                stock_min: import("@prisma/client/runtime/library").Decimal | null;
            } | null;
        } & {
            id_kit: number | null;
            id_producto: number | null;
            cantidad_estandar: import("@prisma/client/runtime/library").Decimal;
            id_detalle: number;
        })[];
    } & {
        id_kit: number;
        nombre_procedimiento: string;
    }) | null>;
    eliminar(idKit: number): Promise<{
        id_kit: number;
        nombre_procedimiento: string;
    }>;
}
