import { Strategy } from 'passport-jwt';
import { UsuariosService } from '../usuarios/usuarios.service';
import { JwtPayload } from './interfaces/jwt-payload.interface';
declare const JwtStrategy_base: new (...args: [opt: import("passport-jwt").StrategyOptionsWithRequest] | [opt: import("passport-jwt").StrategyOptionsWithoutRequest]) => Strategy & {
    validate(...args: any[]): unknown;
};
export declare class JwtStrategy extends JwtStrategy_base {
    private readonly usuariosService;
    constructor(usuariosService: UsuariosService);
    validate(payload: JwtPayload): Promise<{
        id_usuario: number;
        rol: string;
        id_sucursal: number | null;
    }>;
}
export {};
