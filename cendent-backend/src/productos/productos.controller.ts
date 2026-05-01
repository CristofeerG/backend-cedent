import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  ParseIntPipe,
  Patch,
  Post,
  Query,
  Req,
  UseGuards,
  BadRequestException,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiQuery, ApiTags } from '@nestjs/swagger';
import { Roles } from '../auth/decorators/roles.decorator';
import { RolesGuard } from '../auth/guards/roles.guard';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { ActualizarProductoDto } from './dto/actualizar-producto.dto';
import { CrearProductoDto } from './dto/crear-producto.dto';
import { ProductosService } from './productos.service';

@ApiTags('Productos')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('productos')
export class ProductosController {
  constructor(private readonly productosService: ProductosService) {}

  @ApiOperation({ summary: 'Obtener inventario consolidado con stock total por producto vigente' })
  @ApiQuery({ name: 'id_sucursal', required: false, type: Number })
  @Get('inventario')
  obtenerInventario(@Query('id_sucursal') idSucursal?: string) {
    const sucursal = idSucursal ? parseInt(idSucursal, 10) : undefined;
    return this.productosService.obtenerInventario(sucursal);
  }

  @ApiOperation({ summary: 'Buscar productos por nombre (búsqueda parcial, insensible a mayúsculas)' })
  @ApiQuery({ name: 'nombre', required: true, type: String })
  @Get('buscar')
  buscarPorNombre(@Query('nombre') nombre: string) {
    if (!nombre?.trim()) throw new BadRequestException('El parámetro nombre es requerido');
    return this.productosService.buscarPorNombre(nombre.trim());
  }

  @ApiOperation({ summary: 'Listar todos los productos del catálogo' })
  @Get()
  obtenerTodos() {
    return this.productosService.obtenerTodos();
  }

  @ApiOperation({ summary: 'Obtener un producto por ID' })
  @Get(':id')
  obtenerPorId(@Param('id', ParseIntPipe) id: number) {
    return this.productosService.obtenerPorId(id);
  }

  @ApiOperation({ summary: 'Crear producto — solo administrador' })
  @UseGuards(RolesGuard)
  @Roles('administrador')
  @Post()
  crear(@Body() dto: CrearProductoDto, @Req() req: any) {
    return this.productosService.crear(dto, req.user.id_sucursal);
  }

  @ApiOperation({ summary: 'Actualizar datos de un producto — solo administrador' })
  @UseGuards(RolesGuard)
  @Roles('administrador')
  @Patch(':id')
  actualizar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: ActualizarProductoDto,
  ) {
    return this.productosService.actualizar(id, dto);
  }

  @ApiOperation({ summary: 'Eliminar un producto — solo administrador' })
  @UseGuards(RolesGuard)
  @Roles('administrador')
  @Delete(':id')
  eliminar(@Param('id', ParseIntPipe) id: number) {
    return this.productosService.eliminar(id);
  }
}
