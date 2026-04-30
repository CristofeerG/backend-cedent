import { IsInt, IsPositive } from 'class-validator';

export class DespacharKitDto {
  @IsInt()
  @IsPositive()
  id_kit: number;

  @IsInt()
  @IsPositive()
  id_usuario: number;

  @IsInt()
  @IsPositive()
  id_sucursal: number;
}
