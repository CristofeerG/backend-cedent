import {
  Body,
  Controller,
  Get,
  Post,
  Query,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiQuery, ApiTags } from '@nestjs/swagger';
import { DespacharKitDto } from './dto/despachar-kit.dto';
import { MovimientosService } from './movimientos.service';

@ApiTags('Movimientos')
@ApiBearerAuth()
@Controller('movimientos')
export class MovimientosController {
  constructor(private readonly movimientosService: MovimientosService) {}

  @ApiOperation({ summary: 'Listar todos los movimientos, opcionalmente filtrados por sucursal' })
  @ApiQuery({ name: 'id_sucursal', required: false, type: Number })
  @Get()
  obtenerTodos(@Query('id_sucursal') idSucursal?: string) {
    const sucursal = idSucursal ? parseInt(idSucursal, 10) : undefined;
    return this.movimientosService.obtenerTodos(sucursal);
  }

  @ApiOperation({ summary: 'Despachar un kit descontando stock por FIFO' })
  @Post('despachar-kit')
  despacharKit(@Body() dto: DespacharKitDto) {
    return this.movimientosService.despacharKit(
      dto.id_kit,
      dto.id_usuario,
      dto.id_sucursal,
    );
  }
}
