
-- 1) CREACION DE LA BASE DE DATOS
-- Ejecutar esta linea SOLA, conectado a la base "postgres".
-- CREATE DATABASE no puede correr dentro de un bloque de transaccion.
-- Despues conectarse a retail_project y correr el resto del script.
-- CREATE DATABASE retail_project;




-- 2) LIMPIEZA (orden inverso a las dependencias)
DROP TABLE IF EXISTS ventas;
DROP TABLE IF EXISTS productos;
DROP TABLE IF EXISTS clientes;



-- 3) DDL - CREACION DE TABLAS
-- Orden: primero las tablas referenciadas, despues la que referencia.


CREATE TABLE clientes (
    id_cliente  SERIAL       PRIMARY KEY,
    nombre      VARCHAR(100) NOT NULL CHECK (length(trim(nombre)) > 0),
    edad        INT          NOT NULL CHECK (edad BETWEEN 18 AND 120),   -- CHECK 1
    direccion   VARCHAR(100) NOT NULL CHECK (length(trim(direccion)) > 0),
    telefono    VARCHAR(30)  NOT NULL CHECK (length(trim(telefono)) >= 8)
);

CREATE TABLE productos (
    id_producto SERIAL        PRIMARY KEY,
    nombre      VARCHAR(100)  NOT NULL CHECK (length(trim(nombre)) > 0),
    categoria   VARCHAR(50)   NOT NULL,
    precio      NUMERIC(12,2) NOT NULL CHECK (precio > 0),               -- CHECK 2
    stock       INT           NOT NULL CHECK (stock >= 0)
);

CREATE TABLE ventas (
    id_venta    SERIAL      PRIMARY KEY,
    id_cliente  INT         NOT NULL REFERENCES clientes(id_cliente),    -- FK 1
    id_producto INT         NOT NULL REFERENCES productos(id_producto),  -- FK 2
    cantidad    INT         NOT NULL CHECK (cantidad > 0),               -- CHECK 3
    fecha       DATE        NOT NULL CHECK (fecha <= CURRENT_DATE),
    responsable VARCHAR(60) NOT NULL,
    estado      VARCHAR(15) NOT NULL
                CHECK (estado IN ('pendiente', 'procesando', 'enviado', 'entregado'))
);


-- 4) CARGA DE DATOS (transaccion)
-- El orden importa: clientes y productos antes que ventas,
-- porque ventas depende de los IDs generados por los SERIAL.

BEGIN;

INSERT INTO clientes (nombre, edad, direccion, telefono)
VALUES
    ('Metalurgica del Sur SRL', 45, 'Av. Corrientes 1100, CABA',      '1150607080'),
    ('Ferreteria Industrial SA', 38, 'Mitre 2450, Quilmes',           '1145231190'),
    ('Talleres Bermudez',        52, 'Calle 12 Nro 340, Avellaneda',  '1163728451'),
    ('Herramientas Rivas',       29, 'San Martin 780, Lanus',         '1148902233'),
    ('Distribuidora Norte',      61, 'Ruta 8 Km 32, Malvinas Arg.',   '1159887412');

INSERT INTO productos (nombre, categoria, precio, stock)
VALUES
    ('Disco de corte 115mm',        'herramienta', 3000.00, 1000),
    ('Mecha helicoidal HSS 10mm',   'herramienta', 4500.50,  350),
    ('Inserto de torneado CNMG',    'inserto',    12800.00,  120),
    ('Sierra copa bimetalica 32mm', 'herramienta',  9750.00,  80),
    ('Paño abrasivo grano 120',     'abrasivo',     1250.75,  600);

INSERT INTO ventas (id_cliente, id_producto, cantidad, fecha, responsable, estado)
VALUES
    (1, 1, 100, '2026-05-13', 'Juan Gomez',       'pendiente'),
    (2, 3,  25, '2026-06-02', 'Maria Fernandez',  'procesando'),
    (3, 5, 200, '2026-06-18', 'Juan Gomez',       'enviado'),
    (4, 2,  40, '2026-07-09', 'Carlos Duarte',    'entregado'),
    (5, 4,  10, '2026-08-21', 'Maria Fernandez',  'pendiente');

COMMIT;


-- 5) UPDATE - aumento del 10% a toda la categoria "herramienta"
-- En PostgreSQL el alias va despues del nombre de la tabla,
-- y el SET siempre lleva "=".

UPDATE productos
SET    precio = ROUND(precio * 1.10, 2)
WHERE  categoria = 'herramienta';



-- 6) DELETE - elimina UNA venta puntual (por clave primaria)
DELETE FROM ventas
WHERE  id_venta = 5;


-- 7) VERIFICACION

SELECT * FROM clientes  ORDER BY id_cliente;
SELECT * FROM productos ORDER BY id_producto;
SELECT * FROM ventas    ORDER BY id_venta;