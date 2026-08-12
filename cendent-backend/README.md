# CENDENT Backend

SISTEMA WEB PARA LA GESTION DE INVENTARIO Y ANALITICA PREDICTIVA PARA EL CENTRO DE ESPECIALIDADES DANIEL’S CENDENT S.A.. Desarrollado con **NestJS**, **PostgreSQL** y **Prisma ORM**.

---

## Descripción

API REST que gestiona el inventario de materiales, kits de procedimientos, transferencias entre sucursales, movimientos de stock, usuarios y notificaciones en tiempo real. Incluye un módulo de analítica predictiva con Brain.js.

## Tecnologías

- **NestJS 11** — framework principal
- **Prisma 5** — ORM y migraciones
- **PostgreSQL** — base de datos
- **JWT + Passport** — autenticación y control de roles
- **Socket.IO** — notificaciones en tiempo real
- **Brain.js** — analítica predictiva
- **Swagger** — documentación de la API

## Módulos

| Módulo | Descripción |
|---|---|
| `auth` | Autenticación JWT, roles (admin / usuario) |
| `usuarios` | Gestión de cuentas de usuario |
| `sucursales` | Administración de sucursales |
| `productos` | Catálogo de materiales con stock mínimo |
| `lotes` | Control de lotes con fecha de vencimiento |
| `kits` | Kits de procedimientos con detalle de productos |
| `movimientos` | Consumos y despachos de kits |
| `transferencias` | Transferencias de lotes entre sucursales |
| `notificaciones` | Alertas en tiempo real vía WebSockets |
| `analitica` | Predicción de consumo con red neuronal |

---

## Instalación

```bash
npm install
```

## Variables de entorno

Crea un archivo `.env` en la raíz del proyecto con las siguientes variables:

```env
DATABASE_URL="postgresql://usuario:contraseña@localhost:5432/nombre_db"
JWT_SECRET="tu_clave_secreta"
PORT=3000
```

## Base de datos

```bash
# Generar el cliente de Prisma
npx prisma generate

# Ejecutar migraciones
npx prisma migrate dev

# Poblar datos iniciales (seed)
npx prisma db seed
```

## Ejecutar el proyecto

```bash
# Modo desarrollo (con recarga automática)
npx nest start --watch

# Modo producción
npx nest build && node dist/main

# Modo debug
npx nest start --debug --watch
```

## Pruebas y Validación

### Tests unitarios

```bash
# Correr todos los tests
npx jest

# Tests en modo watch (re-ejecuta al guardar)
npx jest --watch

# Con reporte de cobertura
npx jest --coverage

# Tests end-to-end
npx jest --config ./test/jest-e2e.json
```

Los tests unitarios cubren tres módulos críticos sin tocar la base de datos real (todo mockeado con `jest.fn()`):

| Archivo | Qué verifica |
|---|---|
| `src/auth/auth.service.spec.ts` | Login exitoso, usuario no encontrado, contraseña incorrecta, sucursal inactiva |
| `src/auth/guards/roles.guard.spec.ts` | Acceso concedido/denegado según rol, ruta sin restricción de rol |
| `src/transferencias/transferencias.service.spec.ts` | Formato del código de trazabilidad, misma sucursal origen/destino, stock insuficiente |
| `src/analitica/analitica.service.spec.ts` | Retorno de caché, entrenamiento en background, omisión de series cortas |

**Resultado obtenido:**
```
Test Suites: 5 passed, 5 total
Tests:       19 passed, 19 total
Time:        ~21 s
```

---

### Validación del modelo LSTM

```bash
npm run validar:modelo
```

Valida la precisión del modelo de predicción de demanda usando **holdout validation (80% entrenamiento / 20% validación)** sobre los datos históricos reales de cada sucursal. Solo se evalúan productos con ≥ 28 puntos históricos (doble del mínimo requerido en producción).

Métricas calculadas por producto:
- **MAE** (Mean Absolute Error): error absoluto promedio en unidades/día
- **RMSE** (Root Mean Square Error): penaliza más los errores grandes
- **Precisión direccional**: % de días en que se predijo correctamente si el consumo sube o baja

El reporte se imprime en consola y se guarda automáticamente en `docs/validacion-modelo-[FECHA].txt`.

**Resultado obtenido (2026-08-12):**
```
══════════════════════════════════════════════════════
  VALIDACIÓN DEL MODELO LSTM — SISTEMA CENDENT
══════════════════════════════════════════════════════

  Sucursal: El Paraiso
  ─────────────────────────────────────────────────
  Productos validados        :  353
  Productos omitidos (< 28d) :    1
  MAE promedio               :   0.37 u/día
  RMSE promedio              :   0.75 u/día
  Precisión direccional      :   71.1 %
  Error de entrenamiento avg : 0.0211

  Sucursal: Norte
  ─────────────────────────────────────────────────
  Productos validados        :    7
  Productos omitidos (< 28d) :    0
  MAE promedio               :   4.92 u/día
  RMSE promedio              :   5.98 u/día
  Precisión direccional      :   48.7 %
  Error de entrenamiento avg : 0.0438

──────────────────────────────────────────────────
  RESUMEN GLOBAL
──────────────────────────────────────────────────
  Total productos validados  :  360
  MAE global                 :   0.46 u/día
  RMSE global                :   0.85 u/día
  Precisión direccional      :   70.6 %
══════════════════════════════════════════════════════
```

## Linting y formato

```bash
# Formatear código
npx prettier --write "src/**/*.ts" "test/**/*.ts"

# Lint con corrección automática
npx eslint "{src,apps,libs,test}/**/*.ts" --fix
```

---

## Documentación de la API

Una vez levantado el servidor, la documentación Swagger está disponible en:

```
http://localhost:3000/api/docs
```

---

## Estructura del proyecto

```
src/
├── auth/               # Autenticación y guards
├── usuarios/           # CRUD de usuarios
├── sucursales/         # CRUD de sucursales
├── productos/          # Catálogo de materiales
├── lotes/              # Control de lotes
├── kits/               # Kits de procedimientos
├── movimientos/        # Movimientos de stock
├── transferencias/     # Transferencias entre sucursales
├── notificaciones/     # Gateway WebSockets
├── analitica/          # Módulo de IA predictiva
├── prisma/             # Servicio de Prisma
└── common/             # Utilidades compartidas
```
