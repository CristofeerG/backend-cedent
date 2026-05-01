import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsDateString,
  IsInt,
  IsNumber,
  IsOptional,
  Min,
} from 'class-validator';

export class CrearLoteDto {
  @ApiProperty({ description: 'ID del producto al que pertenece el lote', example: 12 })
  @IsInt()
  @Type(() => Number)
  id_producto: number;

  @ApiProperty({ description: 'Stock inicial del lote', example: 50 })
  @IsNumber()
  @Min(0)
  @Type(() => Number)
  stock_inicial: number;

  @ApiProperty({ description: 'Fecha de vencimiento (ISO 8601)', example: '2027-12-31' })
  @IsDateString()
  fecha_venc: string;

  @ApiPropertyOptional({ description: 'Costo unitario', example: 8.75 })
  @IsNumber()
  @Min(0)
  @IsOptional()
  @Type(() => Number)
  costo_unit?: number;
}
