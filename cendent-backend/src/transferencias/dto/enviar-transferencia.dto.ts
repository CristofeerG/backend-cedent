import { Type } from 'class-transformer';
import { IsArray, IsInt, IsPositive, ValidateNested } from 'class-validator';

export class ItemLoteDto {
  @IsInt()
  @IsPositive()
  id_lote: number;

  @IsPositive()
  cantidad: number;
}

export class EnviarTransferenciaDto {
  @IsInt()
  @IsPositive()
  id_sucursal_origen: number;

  @IsInt()
  @IsPositive()
  id_sucursal_destino: number;

  @IsInt()
  @IsPositive()
  id_usuario_envia: number;

  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => ItemLoteDto)
  lotes: ItemLoteDto[];
}
