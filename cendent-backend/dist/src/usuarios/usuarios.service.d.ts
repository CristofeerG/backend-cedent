import { PrismaService } from '../prisma/prisma.service';
import { CrearUsuarioDto } from './dto/crear-usuario.dto';
import { EditarUsuarioDto } from './dto/editar-usuario.dto';
export declare class UsuariosService {
    private readonly prisma;
    constructor(prisma: PrismaService);
    crearUsuario(dto: CrearUsuarioDto): Promise<{
        nom_usuario: string;
        rol: string;
        id_usuario: number;
        id_sucursal: number | null;
    }>;
    buscarPorNomUsuario(nomUsuario: string): Promise<({
        sucursales: {
            id_sucursal: number;
            nom_sucursal: string;
            ubicacion: string | null;
            estado: boolean | null;
        } | null;
    } & {
        nom_usuario: string;
        password_hash: string;
        rol: string;
        id_usuario: number;
        id_sucursal: number | null;
    }) | null>;
    obtenerTodos(): Promise<{
        nom_usuario: string;
        rol: string;
        sucursales: {
            nom_sucursal: string;
        } | null;
        id_usuario: number;
        id_sucursal: number | null;
    }[]>;
    editarUsuario(idUsuario: number, dto: EditarUsuarioDto): Promise<{
        nom_usuario: string;
        rol: string;
        sucursales: {
            nom_sucursal: string;
        } | null;
        id_usuario: number;
        id_sucursal: number | null;
    }>;
    eliminarUsuario(idUsuario: number): Promise<{
        message: string;
    }>;
    obtenerPorId(idUsuario: number): Promise<{
        nom_usuario: string;
        rol: string;
        sucursales: {
            nom_sucursal: string;
        } | null;
        id_usuario: number;
        id_sucursal: number | null;
    }>;
}
