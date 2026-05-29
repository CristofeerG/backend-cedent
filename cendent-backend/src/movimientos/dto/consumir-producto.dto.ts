import { ApiProperty } from '@nestjs/swagger';
import { IsInt, IsPositive } from 'class-validator';

export class ConsumirProductoDto {
  @ApiProperty({ description: 'ID del producto a consumir', example: 26 })
  @IsInt()
  @IsPositive()
  id_producto: number;

  @ApiProperty({ description: 'Cantidad a consumir', example: 2 })
  @IsPositive()
  cantidad: number;
}
