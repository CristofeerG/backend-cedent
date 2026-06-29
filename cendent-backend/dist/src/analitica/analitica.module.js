"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.AnaliticaModule = void 0;
const common_1 = require("@nestjs/common");
const analitica_controller_1 = require("./analitica.controller");
const analitica_scheduler_1 = require("./analitica.scheduler");
const analitica_service_1 = require("./analitica.service");
let AnaliticaModule = class AnaliticaModule {
};
exports.AnaliticaModule = AnaliticaModule;
exports.AnaliticaModule = AnaliticaModule = __decorate([
    (0, common_1.Module)({
        controllers: [analitica_controller_1.AnaliticaController],
        providers: [analitica_service_1.AnaliticaService, analitica_scheduler_1.AnaliticaScheduler],
    })
], AnaliticaModule);
//# sourceMappingURL=analitica.module.js.map