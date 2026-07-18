import { PrismaService } from '../prisma/prisma.service';
import { CrearSucursalDto } from './dto/crear-sucursal.dto';
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
    crear(dto: CrearSucursalDto): import(".prisma/client").Prisma.Prisma__sucursalesClient<{
        id_sucursal: number;
        nom_sucursal: string;
        ubicacion: string | null;
        estado: boolean | null;
    }, never, import("@prisma/client/runtime/library").DefaultArgs>;
}
