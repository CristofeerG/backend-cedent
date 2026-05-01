import {
  BadRequestException,
  Controller,
  Get,
  Param,
  ParseIntPipe,
  Query,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiQuery, ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { SucursalesService } from './sucursales.service';

@ApiTags('Sucursales')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('sucursales')
export class SucursalesController {
  constructor(private readonly sucursalesService: SucursalesService) {}

  @ApiOperation({ summary: 'Buscar sucursales por nombre (búsqueda parcial, insensible a mayúsculas)' })
  @ApiQuery({ name: 'nombre', required: true, type: String })
  @Get('buscar')
  buscarPorNombre(@Query('nombre') nombre: string) {
    if (!nombre?.trim()) throw new BadRequestException('El parámetro nombre es requerido');
    return this.sucursalesService.buscarPorNombre(nombre.trim());
  }

  @ApiOperation({ summary: 'Listar todas las sucursales' })
  @Get()
  obtenerTodas() {
    return this.sucursalesService.obtenerTodas();
  }

  @ApiOperation({ summary: 'Obtener una sucursal por ID' })
  @Get(':id')
  obtenerPorId(@Param('id', ParseIntPipe) id: number) {
    return this.sucursalesService.obtenerPorId(id);
  }
}
