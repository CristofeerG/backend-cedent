import {
  Body,
  Controller,
  Get,
  Param,
  ParseIntPipe,
  Post,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CrearUsuarioDto } from './dto/crear-usuario.dto';
import { UsuariosService } from './usuarios.service';

@ApiTags('Usuarios')
@Controller('usuarios')
export class UsuariosController {
  constructor(private readonly usuariosService: UsuariosService) {}

  @ApiOperation({ summary: 'Registrar un nuevo usuario en el sistema' })
  @Post()
  crearUsuario(@Body() dto: CrearUsuarioDto) {
    return this.usuariosService.crearUsuario(dto);
  }

  @ApiOperation({ summary: 'Listar todos los usuarios (requiere autenticación)' })
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard)
  @Get()
  obtenerTodos() {
    return this.usuariosService.obtenerTodos();
  }

  @ApiOperation({ summary: 'Obtener un usuario por ID (requiere autenticación)' })
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard)
  @Get(':id')
  obtenerPorId(@Param('id', ParseIntPipe) id: number) {
    return this.usuariosService.obtenerPorId(id);
  }
}
