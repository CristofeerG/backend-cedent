import { IsOptional, IsString, MaxLength } from 'class-validator';

export class EditarSucursalDto {
  @IsOptional()
  @IsString()
  @MaxLength(100)
  nomSucursal?: string;

  @IsOptional()
  @IsString()
  @MaxLength(255)
  ubicacion?: string;
}
