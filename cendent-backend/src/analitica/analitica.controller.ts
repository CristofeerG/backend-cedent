import { Controller, Get, Param, ParseIntPipe, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { AnaliticaService } from './analitica.service';

@ApiTags('Analítica')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
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
}
