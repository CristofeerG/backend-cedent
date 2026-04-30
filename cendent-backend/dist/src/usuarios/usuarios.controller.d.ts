import { CrearUsuarioDto } from './dto/crear-usuario.dto';
import { UsuariosService } from './usuarios.service';
export declare class UsuariosController {
    private readonly usuariosService;
    constructor(usuariosService: UsuariosService);
    crearUsuario(dto: CrearUsuarioDto): Promise<{
        id_usuario: number;
        id_sucursal: number | null;
        nom_usuario: string;
        rol: string;
    }>;
    obtenerTodos(): Promise<{
        id_usuario: number;
        sucursales: {
            nom_sucursal: string;
        } | null;
        id_sucursal: number | null;
        nom_usuario: string;
        rol: string;
    }[]>;
    obtenerPorId(id: number): Promise<{
        id_usuario: number;
        sucursales: {
            nom_sucursal: string;
        } | null;
        id_sucursal: number | null;
        nom_usuario: string;
        rol: string;
    }>;
}
