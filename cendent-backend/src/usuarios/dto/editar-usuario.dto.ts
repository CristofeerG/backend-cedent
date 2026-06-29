import { IsInt, IsOptional, IsPositive, IsString, MinLength } from 'class-validator';

export class EditarUsuarioDto {
  @IsString()
  @IsOptional()
  nom_usuario?: string;

  @IsString()
  @MinLength(6)
  @IsOptional()
  password?: string;

  @IsString()
  @IsOptional()
  rol?: string;

  @IsInt()
  @IsPositive()
  @IsOptional()
  id_sucursal?: number;
}
