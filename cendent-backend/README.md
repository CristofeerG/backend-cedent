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

## Pruebas

```bash
# Tests unitarios
npx jest

# Tests en modo watch
npx jest --watch

# Cobertura de tests
npx jest --coverage

# Tests end-to-end
npx jest --config ./test/jest-e2e.json
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
