import { AuthService } from './auth.service';
import { LoginDto } from './dto/login.dto';
export declare class AuthController {
    private readonly authService;
    constructor(authService: AuthService);
    login(dto: LoginDto): Promise<{
        access_token: string;
        id_usuario: number;
        nom_usuario: string;
        rol: string;
        id_sucursal: number | null;
    }>;
}
