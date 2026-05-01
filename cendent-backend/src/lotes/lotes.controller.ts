import {
  Body,
  Controller,
  Get,
  Param,
  ParseIntPipe,
  Post,
  Req,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CrearLoteDto } from './dto/crear-lote.dto';
import { LotesService } from './lotes.service';

@ApiTags('Lotes')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('lotes')
export class LotesController {
  constructor(private readonly lotesService: LotesService) {}

  @ApiOperation({
    summary: 'Registrar un nuevo lote para un producto existente; codigo_lote e id_sucursal se generan automáticamente',
  })
  @Post()
  registrarLote(@Body() dto: CrearLoteDto, @Req() req: any) {
    return this.lotesService.registrarLote(dto, req.user.id_sucursal);
  }

  @ApiOperation({ summary: 'Listar lotes de un producto ordenados por fecha de vencimiento' })
  @Get('producto/:id_producto')
  obtenerPorProducto(@Param('id_producto', ParseIntPipe) idProducto: number) {
    return this.lotesService.obtenerPorProducto(idProducto);
  }
}
