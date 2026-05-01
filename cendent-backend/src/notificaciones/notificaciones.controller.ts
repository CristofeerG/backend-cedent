import { Controller, Post, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Roles } from '../auth/decorators/roles.decorator';
import { RolesGuard } from '../auth/guards/roles.guard';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { NotificacionesService } from './notificaciones.service';

@ApiTags('Notificaciones')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('notificaciones')
export class NotificacionesController {
  constructor(private readonly notificacionesService: NotificacionesService) {}

  @ApiOperation({ summary: 'Forzar revisión inmediata de caducidades y stock mínimo — solo administrador' })
  @UseGuards(RolesGuard)
  @Roles('administrador')
  @Post('revisar')
  revisarAhora() {
    return this.notificacionesService.revisarInventario();
  }
}
