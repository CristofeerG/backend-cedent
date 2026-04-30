CREATE TABLE "sucursales" (
  "id_sucursal" SERIAL PRIMARY KEY,
  "nom_sucursal" VARCHAR(100) NOT NULL,
  "ubicacion" VARCHAR(255),
  "estado" BOOLEAN
);

CREATE TABLE "usuarios" (
  "id_usuario" SERIAL PRIMARY KEY,
  "id_sucursal" INTEGER,
  "nom_usuario" VARCHAR(50) UNIQUE NOT NULL,
  "password_hash" VARCHAR(255) NOT NULL,
  "rol" VARCHAR(20) NOT NULL
);

CREATE TABLE "productos" (  
  "id_producto" SERIAL PRIMARY KEY,
  "nombre_mat" VARCHAR(150) NOT NULL,
  "categoria" VARCHAR(50) DEFAULT 'Odontología',
  "subcategoria" VARCHAR(50),
  "unidad_medida" VARCHAR(30) NOT NULL,
  "stock_min" DECIMAL(10,2) DEFAULT 0
);

CREATE TABLE "lotes" (
  "id_lote" SERIAL PRIMARY KEY,
  "id_producto" INTEGER,
  "id_sucursal" INTEGER,
  "codigo_lote" VARCHAR(80),
  "stock_actual" DECIMAL(10,2) NOT NULL CHECK ("stock_actual" >= 0),
  "costo_unit" DECIMAL(10,2),
  "fecha_venc" DATE NOT NULL,
  "fecha_ingreso" TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE "kits" (
  "id_kit" SERIAL PRIMARY KEY,
  "nombre_procedimiento" VARCHAR(100) NOT NULL
);

CREATE TABLE "detalle_kit" (
  "id_detalle" SERIAL PRIMARY KEY,
  "id_kit" INTEGER,
  "id_producto" INTEGER,
  "cantidad_estandar" DECIMAL(10,2) NOT NULL
);

CREATE TABLE "movimientos" (
  "id_movimiento" SERIAL PRIMARY KEY,
  "id_usuario" INTEGER,
  "id_lote" INTEGER,
  "id_kit" INTEGER,
  "cantidad" DECIMAL(10,2) NOT NULL,
  "fecha_hora" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  "tipo_mov" VARCHAR(50)
);

CREATE TABLE "transferencias" (
    "id_transferencia" SERIAL PRIMARY KEY,
    "codigo_trz" VARCHAR(20) UNIQUE NOT NULL,
    "id_sucursal_origen" INTEGER, 
    "id_sucursal_destino" INTEGER,
    "id_usuario_envia" INTEGER,
    "id_usuario_recibe" INTEGER,
    "estado" VARCHAR(20) DEFAULT 'EN_TRANSITO',
    "fecha_envio" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "fecha_recepcion" TIMESTAMP
);

CREATE TABLE "detalle_transferencia" (
    "id_detalle" SERIAL PRIMARY KEY,
    "id_transferencia" INTEGER,
    "id_lote" INTEGER,
    "cantidad" DECIMAL(10,2) NOT NULL
);

ALTER TABLE "usuarios" ADD FOREIGN KEY ("id_sucursal") REFERENCES "sucursales" ("id_sucursal");

ALTER TABLE "lotes" ADD FOREIGN KEY ("id_producto") REFERENCES "productos" ("id_producto") ON DELETE CASCADE;
ALTER TABLE "lotes" ADD FOREIGN KEY ("id_sucursal") REFERENCES "sucursales" ("id_sucursal");

ALTER TABLE "detalle_kit" ADD FOREIGN KEY ("id_kit") REFERENCES "kits" ("id_kit") ON DELETE CASCADE;
ALTER TABLE "detalle_kit" ADD FOREIGN KEY ("id_producto") REFERENCES "productos" ("id_producto");

ALTER TABLE "movimientos" ADD FOREIGN KEY ("id_usuario") REFERENCES "usuarios" ("id_usuario");
ALTER TABLE "movimientos" ADD FOREIGN KEY ("id_lote") REFERENCES "lotes" ("id_lote");
ALTER TABLE "movimientos" ADD FOREIGN KEY ("id_kit") REFERENCES "kits" ("id_kit");

ALTER TABLE "transferencias" ADD FOREIGN KEY ("id_sucursal_origen") REFERENCES "sucursales"("id_sucursal");
ALTER TABLE "transferencias" ADD FOREIGN KEY ("id_sucursal_destino") REFERENCES "sucursales"("id_sucursal");
ALTER TABLE "transferencias" ADD FOREIGN KEY ("id_usuario_envia") REFERENCES "usuarios"("id_usuario");
ALTER TABLE "transferencias" ADD FOREIGN KEY ("id_usuario_recibe") REFERENCES "usuarios"("id_usuario");

ALTER TABLE "detalle_transferencia" ADD FOREIGN KEY ("id_transferencia") REFERENCES "transferencias"("id_transferencia") ON DELETE CASCADE;
ALTER TABLE "detalle_transferencia" ADD FOREIGN KEY ("id_lote") REFERENCES "lotes"("id_lote");