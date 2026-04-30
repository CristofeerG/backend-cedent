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
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiQuery, ApiTags } from '@nestjs/swagger';
import { ActualizarProductoDto } from './dto/actualizar-producto.dto';
import { CrearProductoDto } from './dto/crear-producto.dto';
import { ProductosService } from './productos.service';

@ApiTags('Productos')
@ApiBearerAuth()
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

  @ApiOperation({ summary: 'Crear un nuevo producto en el catálogo' })
  @Post()
  crear(@Body() dto: CrearProductoDto) {
    return this.productosService.crear(dto);
  }

  @ApiOperation({ summary: 'Actualizar datos de un producto existente' })
  @Patch(':id')
  actualizar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: ActualizarProductoDto,
  ) {
    return this.productosService.actualizar(id, dto);
  }

  @ApiOperation({ summary: 'Eliminar un producto del catálogo' })
  @Delete(':id')
  eliminar(@Param('id', ParseIntPipe) id: number) {
    return this.productosService.eliminar(id);
  }
}
