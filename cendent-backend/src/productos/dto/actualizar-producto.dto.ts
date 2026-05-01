import { Type } from 'class-transformer';
import { IsNumber, IsOptional, IsString, Min } from 'class-validator';

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

  @IsNumber()
  @Min(0)
  @IsOptional()
  @Type(() => Number)
  stock_min?: number;
}
