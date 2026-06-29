import { ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsArray,
  IsNotEmpty,
  IsOptional,
  IsString,
  ValidateNested,
} from 'class-validator';
import { DetalleKitDto } from './crear-kit.dto';

export class ActualizarKitDto {
  @ApiPropertyOptional({ example: 'Restauración (mediana y pequeña)' })
  @IsOptional()
  @IsString()
  @IsNotEmpty()
  nombre_procedimiento?: string;

  @ApiPropertyOptional({ type: [DetalleKitDto] })
  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => DetalleKitDto)
  detalle?: DetalleKitDto[];
}
