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
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { ActualizarKitDto } from './dto/actualizar-kit.dto';
import { CrearKitDto } from './dto/crear-kit.dto';
import { KitsService } from './kits.service';

@ApiTags('Kits')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('kits')
export class KitsController {
  constructor(private readonly kitsService: KitsService) {}

  @ApiOperation({ summary: 'Buscar kits por nombre de procedimiento (búsqueda parcial, insensible a mayúsculas)' })
  @ApiQuery({ name: 'nombre', required: true, type: String })
  @Get('buscar')
  buscarPorNombre(@Query('nombre') nombre: string) {
    if (!nombre?.trim()) throw new BadRequestException('El parámetro nombre es requerido');
    return this.kitsService.buscarPorNombre(nombre.trim());
  }

  @ApiOperation({ summary: 'Listar todos los kits de procedimientos' })
  @Get()
  obtenerTodos() {
    return this.kitsService.obtenerTodos();
  }

  @ApiOperation({ summary: 'Obtener un kit con su detalle de materiales por ID' })
  @Get(':id')
  obtenerPorId(@Param('id', ParseIntPipe) id: number) {
    return this.kitsService.obtenerPorId(id);
  }

  @ApiOperation({ summary: 'Crear un nuevo kit de procedimiento' })
  @Post()
  crear(@Body() dto: CrearKitDto) {
    return this.kitsService.crear(dto);
  }

  @ApiOperation({ summary: 'Actualizar nombre y/o detalle de un kit existente' })
  @Patch(':id')
  actualizar(@Param('id', ParseIntPipe) id: number, @Body() dto: ActualizarKitDto) {
    return this.kitsService.actualizar(id, dto);
  }

  @ApiOperation({ summary: 'Eliminar un kit y su detalle de materiales' })
  @Delete(':id')
  eliminar(@Param('id', ParseIntPipe) id: number) {
    return this.kitsService.eliminar(id);
  }
}
