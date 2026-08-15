import { Controller, Get, Param, ParseIntPipe, Post, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Roles } from '../auth/decorators/roles.decorator';
import { RolesGuard } from '../auth/guards/roles.guard';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { AnaliticaService } from './analitica.service';

@ApiTags('Analítica')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('administrador', 'auxiliar')
@Controller('analitica')
export class AnaliticaController {
  constructor(private readonly analiticaService: AnaliticaService) {}

  @ApiOperation({ summary: 'Entrenar modelo LSTM con historial de egresos de la sucursal' })
  @Get('entrenar/:id_sucursal')
  entrenar(@Param('id_sucursal', ParseIntPipe) idSucursal: number) {
    return this.analiticaService.prepararYEntrenar(idSucursal);
  }

  @ApiOperation({ summary: 'Predecir demanda a 30 días y calcular sugerencias de compra por sucursal' })
  @Get('prediccion/:id_sucursal')
  prediccion(@Param('id_sucursal', ParseIntPipe) idSucursal: number) {
    return this.analiticaService.predecirDemanda(idSucursal);
  }

  @ApiOperation({
    summary: 'Consumo real de las últimas 4 semanas, agregado por semana',
    description:
      'Devuelve el consumo semanal (S-3, S-2, S-1, actual), el total y los ' +
      'id_producto activos en la ventana. El dashboard lo usa para que las ' +
      'barras de consumo real y las de proyección LSTM cubran la misma ' +
      'ventana temporal y el mismo universo de productos.',
  })
  @Get('consumo-real/:id_sucursal')
  consumoReal(@Param('id_sucursal', ParseIntPipe) idSucursal: number) {
    return this.analiticaService.obtenerConsumoReal(idSucursal);
  }

  @ApiOperation({
    summary: 'Forzar reentrenamiento LSTM y actualizar caché de predicción',
    description:
      'Lanza generarYGuardar() sincrónicamente. Con 350+ productos puede tardar varios minutos. ' +
      'Retorna ResultadoPrediccionDto + generado_en con la fecha de actualización.',
  })
  @Post('refrescar/:id_sucursal')
  refrescar(@Param('id_sucursal', ParseIntPipe) idSucursal: number) {
    return this.analiticaService.generarYGuardar(idSucursal);
  }
}
