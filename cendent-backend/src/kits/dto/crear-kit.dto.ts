import { Type } from 'class-transformer';
import {
  IsArray,
  IsInt,
  IsNotEmpty,
  IsPositive,
  IsString,
  ValidateNested,
} from 'class-validator';

export class DetalleKitDto {
  @IsInt()
  @IsPositive()
  id_producto: number;

  @IsPositive()
  cantidad_estandar: number;
}

export class CrearKitDto {
  @IsString()
  @IsNotEmpty()
  nombre_procedimiento: string;

  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => DetalleKitDto)
  detalle: DetalleKitDto[];
}
