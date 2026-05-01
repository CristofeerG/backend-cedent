import { ApiProperty } from '@nestjs/swagger';
import { IsString, Matches } from 'class-validator';

export class RecibirTransferenciaDto {
  @ApiProperty({
    description: 'Código de trazabilidad generado al enviar la transferencia',
    example: 'TRZ-20260429-FUB7D',
  })
  @IsString()
  @Matches(/^TRZ-\d{8}-[A-Z0-9]+$/, {
    message: 'codigo_trz debe tener el formato TRZ-YYYYMMDD-XXXXX',
  })
  codigo_trz: string;
}
