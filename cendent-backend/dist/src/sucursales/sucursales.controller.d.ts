import { SucursalesService } from './sucursales.service';
export declare class SucursalesController {
    private readonly sucursalesService;
    constructor(sucursalesService: SucursalesService);
    buscarPorNombre(nombre: string): import(".prisma/client").Prisma.PrismaPromise<{
        id_sucursal: number;
        nom_sucursal: string;
        ubicacion: string | null;
        estado: boolean | null;
    }[]>;
    obtenerTodas(): import(".prisma/client").Prisma.PrismaPromise<{
        id_sucursal: number;
        nom_sucursal: string;
        ubicacion: string | null;
        estado: boolean | null;
    }[]>;
    obtenerPorId(id: number): Promise<{
        id_sucursal: number;
        nom_sucursal: string;
        ubicacion: string | null;
        estado: boolean | null;
    }>;
}
