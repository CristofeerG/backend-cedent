import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  ParseIntPipe,
  Post,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CrearKitDto } from './dto/crear-kit.dto';
import { KitsService } from './kits.service';

@ApiTags('Kits')
@ApiBearerAuth()
@Controller('kits')
export class KitsController {
  constructor(private readonly kitsService: KitsService) {}

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

  @ApiOperation({ summary: 'Eliminar un kit y su detalle de materiales' })
  @Delete(':id')
  eliminar(@Param('id', ParseIntPipe) id: number) {
    return this.kitsService.eliminar(id);
  }
}
