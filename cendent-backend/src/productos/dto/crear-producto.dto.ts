import {
  IsDecimal,
  IsNotEmpty,
  IsOptional,
  IsString,
} from 'class-validator';

export class CrearProductoDto {
  @IsString()
  @IsNotEmpty()
  nombre_mat: string;

  @IsString()
  @IsOptional()
  categoria?: string;

  @IsString()
  @IsOptional()
  subcategoria?: string;

  @IsString()
  @IsNotEmpty()
  unidad_medida: string;

  @IsDecimal()
  @IsOptional()
  stock_min?: number;
}
