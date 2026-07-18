import { IsBoolean, IsNotEmpty, IsOptional, IsString, MaxLength } from 'class-validator';

export class CrearSucursalDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(100)
  nomSucursal: string;

  @IsOptional()
  @IsString()
  @MaxLength(255)
  ubicacion?: string;

  @IsOptional()
  @IsBoolean()
  estado?: boolean;
}
