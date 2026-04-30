import { Controller, Post, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { NotificacionesService } from './notificaciones.service';

@ApiTags('Notificaciones')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('notificaciones')
export class NotificacionesController {
  constructor(private readonly notificacionesService: NotificacionesService) {}

  @ApiOperation({ summary: 'Forzar revisión inmediata de caducidades y stock mínimo (normalmente corre a medianoche)' })
  @Post('revisar')
  revisarAhora() {
    return this.notificacionesService.revisarInventario();
  }
}
