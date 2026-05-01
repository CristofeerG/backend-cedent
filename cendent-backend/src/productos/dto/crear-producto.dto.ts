import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsDateString,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  Min,
} from 'class-validator';

export class CrearProductoDto {
  @ApiProperty({ example: 'Alginato Cromo Rojo' })
  @IsString()
  @IsNotEmpty()
  nombre_mat: string;

  @ApiPropertyOptional({ example: 'Odontología' })
  @IsString()
  @IsOptional()
  categoria?: string;

  @ApiPropertyOptional({ example: 'Material de Impresión' })
  @IsString()
  @IsOptional()
  subcategoria?: string;

  @ApiProperty({ example: 'Kg' })
  @IsString()
  @IsNotEmpty()
  unidad_medida: string;

  @ApiPropertyOptional({ example: 5 })
  @IsNumber()
  @Min(0)
  @IsOptional()
  @Type(() => Number)
  stock_min?: number;

  // ── campos opcionales del lote inicial ──────────────────────────────────────

  @ApiPropertyOptional({ description: 'Stock inicial del primer lote', example: 100 })
  @IsNumber()
  @Min(0)
  @IsOptional()
  @Type(() => Number)
  stock_inicial?: number;

  @ApiPropertyOptional({ description: 'Fecha de vencimiento del lote (ISO 8601)', example: '2027-06-30' })
  @IsDateString()
  @IsOptional()
  fecha_venc?: string;

  @ApiPropertyOptional({ description: 'Costo unitario del lote', example: 12.5 })
  @IsNumber()
  @Min(0)
  @IsOptional()
  @Type(() => Number)
  costo_unit?: number;
}
