import { PrismaService } from '../prisma/prisma.service';
import { CrearUsuarioDto } from './dto/crear-usuario.dto';
export declare class UsuariosService {
    private readonly prisma;
    constructor(prisma: PrismaService);
    crearUsuario(dto: CrearUsuarioDto): Promise<{
        id_usuario: number;
        id_sucursal: number | null;
        nom_usuario: string;
        rol: string;
    }>;
    buscarPorNomUsuario(nomUsuario: string): Promise<({
        sucursales: {
            id_sucursal: number;
            nom_sucursal: string;
            ubicacion: string | null;
            estado: boolean | null;
        } | null;
    } & {
        id_usuario: number;
        id_sucursal: number | null;
        nom_usuario: string;
        rol: string;
        password_hash: string;
    }) | null>;
    obtenerTodos(): Promise<{
        id_usuario: number;
        sucursales: {
            nom_sucursal: string;
        } | null;
        id_sucursal: number | null;
        nom_usuario: string;
        rol: string;
    }[]>;
    obtenerPorId(idUsuario: number): Promise<{
        id_usuario: number;
        sucursales: {
            nom_sucursal: string;
        } | null;
        id_sucursal: number | null;
        nom_usuario: string;
        rol: string;
    }>;
}
