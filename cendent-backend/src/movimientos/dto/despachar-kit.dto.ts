import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsArray,
  IsInt,
  IsOptional,
  IsPositive,
  ValidateNested,
} from 'class-validator';

export class SustitucionDto {
  @ApiProperty({ description: 'id_detalle del ítem variable dentro del kit', example: 3 })
  @IsInt()
  @IsPositive()
  id_detalle: number;

  @ApiProperty({ description: 'ID del producto concreto elegido por el odontólogo', example: 12 })
  @IsInt()
  @IsPositive()
  id_producto: number;
}

export class DespacharKitDto {
  @ApiProperty({ description: 'ID del kit a despachar', example: 1 })
  @IsInt()
  @IsPositive()
  id_kit: number;

  @ApiPropertyOptional({
    description: 'Producto elegido para cada ítem variable del kit',
    type: [SustitucionDto],
  })
  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => SustitucionDto)
  sustituciones?: SustitucionDto[];
}
