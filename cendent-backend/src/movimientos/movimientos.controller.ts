import {
  Body,
  Controller,
  Get,
  Post,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiQuery, ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { ConsumirProductoDto } from './dto/consumir-producto.dto';
import { DespacharKitDto } from './dto/despachar-kit.dto';
import { MovimientosService } from './movimientos.service';

@ApiTags('Movimientos')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
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

  @ApiOperation({ summary: 'Despachar un kit; usuario y sucursal se extraen del JWT' })
  @Post('despachar-kit')
  despacharKit(@Body() dto: DespacharKitDto, @Req() req: any) {
    return this.movimientosService.despacharKit(
      dto.id_kit,
      req.user.id_usuario,
      req.user.id_sucursal,
      dto.sustituciones ?? [],
    );
  }

  @ApiOperation({ summary: 'Consumo directo de un producto sin kit (EGRESO_DIRECTO); usuario y sucursal se extraen del JWT' })
  @Post('consumir')
  consumirProducto(@Body() dto: ConsumirProductoDto, @Req() req: any) {
    return this.movimientosService.consumirProducto(
      dto.id_producto,
      dto.cantidad,
      req.user.id_usuario,
      req.user.id_sucursal,
    );
  }
}
