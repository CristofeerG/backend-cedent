import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsDateString, IsNumber, IsOptional, Min } from 'class-validator';

export class ActualizarLoteDto {
  @ApiPropertyOptional({ description: 'Stock actual del lote', example: 50 })
  @IsOptional()
  @IsNumber()
  @Min(0)
  stock_actual?: number;

  @ApiPropertyOptional({ description: 'Costo unitario; enviar null para limpiar', example: 12.5, nullable: true })
  @IsOptional()
  @IsNumber()
  @Min(0)
  costo_unit?: number | null;

  @ApiPropertyOptional({ description: 'Fecha de vencimiento en formato ISO', example: '2027-06-30' })
  @IsOptional()
  @IsDateString()
  fecha_venc?: string;
}
