import { JwtService } from '@nestjs/jwt';
import { UsuariosService } from '../usuarios/usuarios.service';
import { LoginDto } from './dto/login.dto';
export declare class AuthService {
    private readonly usuariosService;
    private readonly jwtService;
    constructor(usuariosService: UsuariosService, jwtService: JwtService);
    login(dto: LoginDto): Promise<{
        access_token: string;
        id_usuario: number;
        nom_usuario: string;
        rol: string;
        id_sucursal: number | null;
        nom_sucursal: string;
    }>;
}
