import { IsDecimal, IsOptional, IsString } from 'class-validator';

export class ActualizarProductoDto {
  @IsString()
  @IsOptional()
  nombre_mat?: string;

  @IsString()
  @IsOptional()
  categoria?: string;

  @IsString()
  @IsOptional()
  subcategoria?: string;

  @IsString()
  @IsOptional()
  unidad_medida?: string;

  @IsDecimal()
  @IsOptional()
  stock_min?: number;
}
