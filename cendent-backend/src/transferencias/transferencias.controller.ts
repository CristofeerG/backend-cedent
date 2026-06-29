import {
  Body,
  Controller,
  Get,
  Param,
  ParseIntPipe,
  Patch,
  Post,
  Req,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Roles } from '../auth/decorators/roles.decorator';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { EnviarTransferenciaDto } from './dto/enviar-transferencia.dto';
import { RecibirTransferenciaDto } from './dto/recibir-transferencia.dto';
import { TransferenciasService } from './transferencias.service';

@ApiTags('Transferencias')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('administrador', 'auxiliar')
@Controller('transferencias')
export class TransferenciasController {
  constructor(private readonly transferenciasService: TransferenciasService) {}

  @ApiOperation({ summary: 'Listar todas las transferencias de la sucursal del usuario' })
  @Get()
  obtenerTodas(@Req() req: any) {
    return this.transferenciasService.obtenerTodas(req.user.id_sucursal);
  }

  @ApiOperation({ summary: 'Obtener una transferencia por ID' })
  @Get(':id')
  obtenerPorId(@Param('id', ParseIntPipe) id: number) {
    return this.transferenciasService.obtenerPorId(id);
  }

  @ApiOperation({ summary: 'Crear transferencia por nombre de producto con FIFO; sucursal origen y usuario se extraen del JWT' })
  @Post('enviar')
  enviarTransferencia(@Body() dto: EnviarTransferenciaDto, @Req() req: any) {
    return this.transferenciasService.enviarTransferencia(
      dto,
      req.user.id_sucursal,
      req.user.id_usuario,
    );
  }

  @ApiOperation({ summary: 'Cancelar una transferencia EN_TRANSITO y restaurar stock en origen' })
  @Patch(':id/cancelar')
  cancelarTransferencia(@Param('id', ParseIntPipe) id: number) {
    return this.transferenciasService.cancelarTransferencia(id);
  }

  @ApiOperation({ summary: 'Registrar la recepción de una transferencia; usuario recibe se extrae del JWT' })
  @Post('recibir')
  recibirTransferencia(@Body() dto: RecibirTransferenciaDto, @Req() req: any) {
    return this.transferenciasService.recibirTransferencia(dto, req.user.id_usuario);
  }
}
