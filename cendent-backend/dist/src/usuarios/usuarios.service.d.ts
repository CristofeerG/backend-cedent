import { PrismaService } from '../prisma/prisma.service';
import { CrearUsuarioDto } from './dto/crear-usuario.dto';
import { EditarUsuarioDto } from './dto/editar-usuario.dto';
export declare class UsuariosService {
    private readonly prisma;
    constructor(prisma: PrismaService);
    crearUsuario(dto: CrearUsuarioDto): Promise<{
        id_usuario: number;
        id_sucursal: number | null;
        rol: string;
        nom_usuario: string;
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
        rol: string;
        nom_usuario: string;
        password_hash: string;
    }) | null>;
    obtenerTodos(): Promise<{
        id_usuario: number;
        id_sucursal: number | null;
        sucursales: {
            nom_sucursal: string;
        } | null;
        rol: string;
        nom_usuario: string;
    }[]>;
    editarUsuario(idUsuario: number, dto: EditarUsuarioDto): Promise<{
        id_usuario: number;
        id_sucursal: number | null;
        sucursales: {
            nom_sucursal: string;
        } | null;
        rol: string;
        nom_usuario: string;
    }>;
    eliminarUsuario(idUsuario: number): Promise<{
        message: string;
    }>;
    obtenerPorId(idUsuario: number): Promise<{
        id_usuario: number;
        id_sucursal: number | null;
        sucursales: {
            nom_sucursal: string;
        } | null;
        rol: string;
        nom_usuario: string;
    }>;
}
