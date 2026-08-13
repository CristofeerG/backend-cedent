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
import { RolesGuard } from '../auth/guards/roles.guard';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { ActualizarLoteDto } from './dto/actualizar-lote.dto';
import { CrearLoteDto } from './dto/crear-lote.dto';
import { LotesService } from './lotes.service';

@ApiTags('Lotes')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('lotes')
export class LotesController {
  constructor(private readonly lotesService: LotesService) {}

  @ApiOperation({ summary: 'Registrar un nuevo lote para un producto existente; codigo_lote e id_sucursal se generan automáticamente' })
  @Post()
  registrarLote(@Body() dto: CrearLoteDto, @Req() req: any) {
    return this.lotesService.registrarLote(dto, req.user.id_sucursal);
  }

  @ApiOperation({ summary: 'Listar lotes de un producto en la sucursal del usuario autenticado' })
  @Get('producto/:id_producto')
  obtenerPorProducto(
    @Param('id_producto', ParseIntPipe) idProducto: number,
    @Req() req: any,
  ) {
    return this.lotesService.obtenerPorProducto(idProducto, req.user.id_sucursal as number);
  }

  @ApiOperation({ summary: 'Dar de baja un lote (requiere stock en 0) — solo administrador' })
  @UseGuards(RolesGuard)
  @Roles('administrador')
  @Patch(':id/baja')
  darDeBaja(@Param('id', ParseIntPipe) id: number, @Req() req: any) {
    return this.lotesService.darDeBaja(id, req.user.id_sucursal);
  }

  @ApiOperation({ summary: 'Actualizar stock, costo o fecha de vencimiento de un lote — solo administrador' })
  @UseGuards(RolesGuard)
  @Roles('administrador')
  @Patch(':id')
  actualizar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: ActualizarLoteDto,
  ) {
    return this.lotesService.actualizar(id, dto);
  }
}
