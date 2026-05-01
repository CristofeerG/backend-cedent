import { ApiProperty } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsArray,
  IsNotEmpty,
  IsNumber,
  IsString,
  Min,
  ValidateNested,
} from 'class-validator';

export class ItemProductoTransferenciaDto {
  @ApiProperty({ description: 'Nombre (parcial) del producto a transferir', example: 'Alginato' })
  @IsString()
  @IsNotEmpty()
  nombre_producto: string;

  @ApiProperty({ description: 'Cantidad total a transferir', example: 10 })
  @IsNumber()
  @Min(1)
  cantidad: number;
}

export class EnviarTransferenciaDto {
  @ApiProperty({ description: 'Nombre (parcial) de la sucursal destino', example: 'Norte' })
  @IsString()
  @IsNotEmpty()
  nombre_sucursal_destino: string;

  @ApiProperty({ type: [ItemProductoTransferenciaDto] })
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => ItemProductoTransferenciaDto)
  productos: ItemProductoTransferenciaDto[];
}
