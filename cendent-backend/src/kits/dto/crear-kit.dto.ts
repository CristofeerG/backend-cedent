import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsArray,
  IsBoolean,
  IsInt,
  IsNotEmpty,
  IsOptional,
  IsPositive,
  IsString,
  ValidateNested,
} from 'class-validator';

export class DetalleKitDto {
  @ApiPropertyOptional({
    description: 'ID del producto. Puede ser null solo cuando es_variable es true',
    nullable: true,
    example: 5,
  })
  @IsOptional()
  @IsInt()
  @IsPositive()
  id_producto?: number | null;

  @ApiProperty({ example: 1 })
  @IsPositive()
  cantidad_estandar: number;

  @ApiPropertyOptional({
    description: 'true = el odontólogo elige el producto concreto en el despacho',
    default: false,
  })
  @IsOptional()
  @IsBoolean()
  es_variable?: boolean;
}

export class CrearKitDto {
  @ApiProperty({ example: 'Restauración (mediana y pequeña)' })
  @IsString()
  @IsNotEmpty()
  nombre_procedimiento: string;

  @ApiProperty({ type: [DetalleKitDto] })
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => DetalleKitDto)
  detalle: DetalleKitDto[];
}
