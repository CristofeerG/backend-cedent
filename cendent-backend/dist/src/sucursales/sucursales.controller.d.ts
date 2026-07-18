import { CrearSucursalDto } from './dto/crear-sucursal.dto';
import { SucursalesService } from './sucursales.service';
export declare class SucursalesController {
    private readonly sucursalesService;
    constructor(sucursalesService: SucursalesService);
    crear(dto: CrearSucursalDto): import(".prisma/client").Prisma.Prisma__sucursalesClient<{
        nom_sucursal: string;
        ubicacion: string | null;
        estado: boolean | null;
        id_sucursal: number;
    }, never, import("@prisma/client/runtime/library").DefaultArgs>;
    buscarPorNombre(nombre: string): import(".prisma/client").Prisma.PrismaPromise<{
        nom_sucursal: string;
        ubicacion: string | null;
        estado: boolean | null;
        id_sucursal: number;
    }[]>;
    obtenerTodas(): import(".prisma/client").Prisma.PrismaPromise<{
        nom_sucursal: string;
        ubicacion: string | null;
        estado: boolean | null;
        id_sucursal: number;
    }[]>;
    obtenerPorId(id: number): Promise<{
        nom_sucursal: string;
        ubicacion: string | null;
        estado: boolean | null;
        id_sucursal: number;
    }>;
}
