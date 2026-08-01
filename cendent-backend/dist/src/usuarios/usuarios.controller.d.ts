import { CrearUsuarioDto } from './dto/crear-usuario.dto';
import { EditarUsuarioDto } from './dto/editar-usuario.dto';
import { UsuariosService } from './usuarios.service';
export declare class UsuariosController {
    private readonly usuariosService;
    constructor(usuariosService: UsuariosService);
    crearUsuario(dto: CrearUsuarioDto): Promise<{
        nom_usuario: string;
        rol: string;
        id_usuario: number;
        id_sucursal: number | null;
    }>;
    obtenerTodos(): Promise<{
        nom_usuario: string;
        rol: string;
        sucursales: {
            nom_sucursal: string;
        } | null;
        id_usuario: number;
        id_sucursal: number | null;
    }[]>;
    obtenerPorId(id: number): Promise<{
        nom_usuario: string;
        rol: string;
        sucursales: {
            nom_sucursal: string;
        } | null;
        id_usuario: number;
        id_sucursal: number | null;
    }>;
    editarUsuario(id: number, dto: EditarUsuarioDto): Promise<{
        nom_usuario: string;
        rol: string;
        sucursales: {
            nom_sucursal: string;
        } | null;
        id_usuario: number;
        id_sucursal: number | null;
    }>;
    eliminarUsuario(id: number): Promise<{
        message: string;
    }>;
}
