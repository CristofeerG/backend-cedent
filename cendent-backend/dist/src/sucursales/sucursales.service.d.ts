import { PrismaService } from '../prisma/prisma.service';
export declare class SucursalesService {
    private readonly prisma;
    constructor(prisma: PrismaService);
    obtenerTodas(): import(".prisma/client").Prisma.PrismaPromise<{
        id_sucursal: number;
        nom_sucursal: string;
        ubicacion: string | null;
        estado: boolean | null;
    }[]>;
    obtenerPorId(idSucursal: number): Promise<{
        id_sucursal: number;
        nom_sucursal: string;
        ubicacion: string | null;
        estado: boolean | null;
    }>;
    buscarPorNombre(nombre: string): import(".prisma/client").Prisma.PrismaPromise<{
        id_sucursal: number;
        nom_sucursal: string;
        ubicacion: string | null;
        estado: boolean | null;
    }[]>;
}
