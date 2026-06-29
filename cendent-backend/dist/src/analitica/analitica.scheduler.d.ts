import { PrismaService } from '../prisma/prisma.service';
import { AnaliticaService } from './analitica.service';
export declare class AnaliticaScheduler {
    private readonly analiticaService;
    private readonly prisma;
    private readonly logger;
    constructor(analiticaService: AnaliticaService, prisma: PrismaService);
    generarTodasLasPredicciones(): Promise<void>;
}
