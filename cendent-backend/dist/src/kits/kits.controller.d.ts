import { CrearKitDto } from './dto/crear-kit.dto';
import { KitsService } from './kits.service';
export declare class KitsController {
    private readonly kitsService;
    constructor(kitsService: KitsService);
    buscarPorNombre(nombre: string): import(".prisma/client").Prisma.PrismaPromise<({
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
            es_variable: boolean;
            id_detalle: number;
        })[];
    } & {
        id_kit: number;
        nombre_procedimiento: string;
    })[]>;
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
            es_variable: boolean;
            id_detalle: number;
        })[];
    } & {
        id_kit: number;
        nombre_procedimiento: string;
    })[]>;
    obtenerPorId(id: number): Promise<{
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
            es_variable: boolean;
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
            es_variable: boolean;
            id_detalle: number;
        })[];
    } & {
        id_kit: number;
        nombre_procedimiento: string;
    }) | null>;
    eliminar(id: number): Promise<{
        id_kit: number;
        nombre_procedimiento: string;
    }>;
}
