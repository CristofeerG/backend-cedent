import {
  Body,
  Controller,
  Get,
  Param,
  ParseIntPipe,
  Post,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { EnviarTransferenciaDto } from './dto/enviar-transferencia.dto';
import { RecibirTransferenciaDto } from './dto/recibir-transferencia.dto';
import { TransferenciasService } from './transferencias.service';

@ApiTags('Transferencias')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('transferencias')
export class TransferenciasController {
  constructor(private readonly transferenciasService: TransferenciasService) {}

  @ApiOperation({ summary: 'Listar todas las transferencias' })
  @Get()
  obtenerTodas() {
    return this.transferenciasService.obtenerTodas();
  }

  @ApiOperation({ summary: 'Obtener una transferencia por ID' })
  @Get(':id')
  obtenerPorId(@Param('id', ParseIntPipe) id: number) {
    return this.transferenciasService.obtenerPorId(id);
  }

  @ApiOperation({ summary: 'Crear una transferencia de stock entre sucursales (descuenta origen)' })
  @Post('enviar')
  enviarTransferencia(@Body() dto: EnviarTransferenciaDto) {
    return this.transferenciasService.enviarTransferencia(dto);
  }

  @ApiOperation({ summary: 'Registrar la recepción de una transferencia (acredita destino)' })
  @Post('recibir')
  recibirTransferencia(@Body() dto: RecibirTransferenciaDto) {
    return this.transferenciasService.recibirTransferencia(dto);
  }
}
