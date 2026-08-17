import { CrearUsuarioDto } from './dto/crear-usuario.dto';
import { EditarUsuarioDto } from './dto/editar-usuario.dto';
import { UsuariosService } from './usuarios.service';
export declare class UsuariosController {
    private readonly usuariosService;
    constructor(usuariosService: UsuariosService);
    crearUsuario(dto: CrearUsuarioDto): Promise<{
        id_usuario: number;
        id_sucursal: number | null;
        rol: string;
        nom_usuario: string;
    }>;
    obtenerTodos(): Promise<{
        id_usuario: number;
        id_sucursal: number | null;
        sucursales: {
            nom_sucursal: string;
        } | null;
        rol: string;
        nom_usuario: string;
    }[]>;
    obtenerPorId(id: number): Promise<{
        id_usuario: number;
        id_sucursal: number | null;
        sucursales: {
            nom_sucursal: string;
        } | null;
        rol: string;
        nom_usuario: string;
    }>;
    editarUsuario(id: number, dto: EditarUsuarioDto): Promise<{
        id_usuario: number;
        id_sucursal: number | null;
        sucursales: {
            nom_sucursal: string;
        } | null;
        rol: string;
        nom_usuario: string;
    }>;
    eliminarUsuario(id: number): Promise<{
        message: string;
    }>;
}
