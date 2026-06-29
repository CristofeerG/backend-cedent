import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  ParseIntPipe,
  Patch,
  Post,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Roles } from '../auth/decorators/roles.decorator';
import { RolesGuard } from '../auth/guards/roles.guard';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CrearUsuarioDto } from './dto/crear-usuario.dto';
import { EditarUsuarioDto } from './dto/editar-usuario.dto';
import { UsuariosService } from './usuarios.service';

@ApiTags('Usuarios')
@Controller('usuarios')
export class UsuariosController {
  constructor(private readonly usuariosService: UsuariosService) {}

  @ApiOperation({ summary: 'Registrar un nuevo usuario en el sistema' })
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('administrador')
  @Post()
  crearUsuario(@Body() dto: CrearUsuarioDto) {
    return this.usuariosService.crearUsuario(dto);
  }

  @ApiOperation({ summary: 'Listar todos los usuarios — solo administrador' })
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('administrador')
  @Get()
  obtenerTodos() {
    return this.usuariosService.obtenerTodos();
  }

  @ApiOperation({ summary: 'Obtener un usuario por ID — solo administrador' })
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('administrador')
  @Get(':id')
  obtenerPorId(@Param('id', ParseIntPipe) id: number) {
    return this.usuariosService.obtenerPorId(id);
  }

  @ApiOperation({ summary: 'Editar un usuario existente — solo administrador' })
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('administrador')
  @Patch(':id')
  editarUsuario(@Param('id', ParseIntPipe) id: number, @Body() dto: EditarUsuarioDto) {
    return this.usuariosService.editarUsuario(id, dto);
  }

  @ApiOperation({ summary: 'Eliminar un usuario — solo administrador' })
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('administrador')
  @Delete(':id')
  eliminarUsuario(@Param('id', ParseIntPipe) id: number) {
    return this.usuariosService.eliminarUsuario(id);
  }
}
