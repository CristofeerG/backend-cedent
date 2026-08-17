import { BadRequestException, Controller, Post, Req, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { NotificacionesService } from './notificaciones.service';

@ApiTags('Notificaciones')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('notificaciones')
export class NotificacionesController {
  constructor(private readonly notificacionesService: NotificacionesService) {}

  @ApiOperation({
    summary: 'Forzar revisión inmediata de caducidades y stock mínimo de la propia sucursal',
    description:
      'La sucursal se toma del token, no del cliente. Antes este endpoint ' +
      'revisaba todo el inventario y notificaba a todos los usuarios ' +
      'conectados, así que un refresco desde una sucursal alertaba a las demás.',
  })
  @Post('revisar')
  revisarAhora(@Req() req: { user?: { id_sucursal?: number | null } }) {
    const idSucursal = req.user?.id_sucursal;
    if (idSucursal == null) {
      throw new BadRequestException('El usuario no tiene una sucursal asignada.');
    }
    return this.notificacionesService.revisarSucursal(idSucursal);
  }
}
