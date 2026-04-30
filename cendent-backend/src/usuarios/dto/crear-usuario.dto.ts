import { IsInt, IsNotEmpty, IsOptional, IsPositive, IsString, MinLength } from 'class-validator';

export class CrearUsuarioDto {
  @IsString()
  @IsNotEmpty()
  nom_usuario: string;

  @IsString()
  @MinLength(6)
  password: string;

  @IsString()
  @IsNotEmpty()
  rol: string;

  @IsInt()
  @IsPositive()
  @IsOptional()
  id_sucursal?: number;
}
