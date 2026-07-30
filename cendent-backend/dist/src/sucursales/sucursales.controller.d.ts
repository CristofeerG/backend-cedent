import { CrearSucursalDto } from './dto/crear-sucursal.dto';
import { SucursalesService } from './sucursales.service';
export declare class SucursalesController {
    private readonly sucursalesService;
    constructor(sucursalesService: SucursalesService);
    crear(dto: CrearSucursalDto): import(".prisma/client").Prisma.Prisma__sucursalesClient<{
        id_sucursal: number;
        nom_sucursal: string;
        ubicacion: string | null;
        estado: boolean | null;
    }, never, import("@prisma/client/runtime/library").DefaultArgs>;
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
