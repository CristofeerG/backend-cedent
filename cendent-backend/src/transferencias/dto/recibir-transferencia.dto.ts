import { IsInt, IsPositive } from 'class-validator';

export class RecibirTransferenciaDto {
  @IsInt()
  @IsPositive()
  id_transferencia: number;

  @IsInt()
  @IsPositive()
  id_usuario_recibe: number;
}
