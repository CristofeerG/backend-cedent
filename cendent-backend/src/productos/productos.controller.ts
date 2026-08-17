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
  ForbiddenException,
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

  @ApiOperation({
    summary:
      'Obtener inventario con stock total por producto vigente — sólo la sucursal del usuario',
    description:
      'La sucursal sale siempre del JWT. Antes el rol administrador se ' +
      'saltaba el filtro y recibía el inventario consolidado de todas las ' +
      'sucursales, de modo que un administrador de una sucursal pequeña veía ' +
      'sobre todo los productos de la más grande.',
  })
  @ApiQuery({ name: 'id_sucursal', required: false, type: Number })
  @Get('inventario')
  obtenerInventario(
    @Req() req: any,
    @Query('id_sucursal') idSucursalQuery?: string,
  ) {
    const idSucursal = req.user?.id_sucursal as number | null | undefined;
    if (idSucursal == null) {
      throw new BadRequestException('El usuario no tiene una sucursal asignada.');
    }

    // El cliente manda id_sucursal para separar su caché por sucursal, pero la
    // sucursal efectiva es la del token. Si no coinciden se rechaza en vez de
    // ignorar el parámetro en silencio: ese silencio fue justamente lo que
    // ocultó que el filtro no se estaba aplicando.
    if (idSucursalQuery !== undefined) {
      const pedido = Number(idSucursalQuery);
      if (!Number.isInteger(pedido) || pedido !== idSucursal) {
        throw new ForbiddenException(
          'No puede consultar el inventario de otra sucursal.',
        );
      }
    }

    return this.productosService.obtenerInventario(idSucursal);
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
