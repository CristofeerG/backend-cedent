import {
  BadRequestException,
  Body,
  Controller,
  Delete,
  Get,
  Param,
  ParseIntPipe,
  Patch,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiQuery, ApiTags } from '@nestjs/swagger';
import { Roles } from '../auth/decorators/roles.decorator';
import { RolesGuard } from '../auth/guards/roles.guard';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CrearSucursalDto } from './dto/crear-sucursal.dto';
import { EditarSucursalDto } from './dto/editar-sucursal.dto';
import { SucursalesService } from './sucursales.service';

@ApiTags('Sucursales')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('sucursales')
export class SucursalesController {
  constructor(private readonly sucursalesService: SucursalesService) {}

  @ApiOperation({ summary: 'Crear una nueva sucursal — solo administrador' })
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('administrador')
  @Post()
  crear(@Body() dto: CrearSucursalDto) {
    return this.sucursalesService.crear(dto);
  }

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

  @ApiOperation({ summary: 'Editar nombre o ubicación de una sucursal — solo administrador' })
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('administrador')
  @Patch(':id')
  actualizar(@Param('id', ParseIntPipe) id: number, @Body() dto: EditarSucursalDto) {
    return this.sucursalesService.actualizar(id, dto);
  }

  @ApiOperation({ summary: 'Desactivar (eliminar) una sucursal — solo administrador' })
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('administrador')
  @Delete(':id')
  eliminar(@Param('id', ParseIntPipe) id: number) {
    return this.sucursalesService.eliminar(id);
  }
}
