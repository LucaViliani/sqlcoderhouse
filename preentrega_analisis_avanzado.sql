-- =====================================================================
-- preentrega_analisis_avanzado.sql
-- Análisis de ventas con CTEs, Window Functions y lógica condicional
-- =====================================================================

-- 1) CREACIÓN DE LA BASE
-- Ejecutar por separado y luego conectarse a la base antes de seguir:
-- CREATE DATABASE pre_entrega_5;


-- 2) CREACIÓN DE TABLAS
-- clientes y productos son tablas maestras; ventas las referencia por FK.

CREATE TABLE clientes (
    id_cliente  SERIAL       PRIMARY KEY,
    nombre      VARCHAR(100) NOT NULL CHECK (length(trim(nombre)) > 0),
    edad        INT          NOT NULL CHECK (edad BETWEEN 18 AND 120),
    direccion   VARCHAR(100) NOT NULL CHECK (length(trim(direccion)) > 0),
    telefono    VARCHAR(30)  NOT NULL CHECK (length(trim(telefono)) >= 8)
);

CREATE TABLE productos (
    id_producto SERIAL        PRIMARY KEY,
    nombre      VARCHAR(100)  NOT NULL CHECK (length(trim(nombre)) > 0),
    categoria   VARCHAR(50)   NOT NULL,
    precio      NUMERIC(12,2) NOT NULL CHECK (precio > 0),
    stock       INT           NOT NULL CHECK (stock >= 0)
);

CREATE TABLE ventas (
    id_venta    SERIAL      PRIMARY KEY,
    id_cliente  INT         NOT NULL REFERENCES clientes(id_cliente),
    id_producto INT         NOT NULL REFERENCES productos(id_producto),
    cantidad    INT         NOT NULL CHECK (cantidad > 0),
    fecha       DATE        NOT NULL CHECK (fecha <= CURRENT_DATE),
    responsable VARCHAR(60) NOT NULL,
    estado      VARCHAR(15) NOT NULL
                CHECK (estado IN ('pendiente', 'procesando', 'enviado', 'entregado'))
);


-- 3) CARGA DE DATOS (transacción)
-- Primero clientes y productos, porque ventas depende de sus IDs.
-- Se cargan varias categorías por mes para que el ranking sea significativo.

BEGIN;

INSERT INTO clientes (nombre, edad, direccion, telefono) VALUES
    ('Metalurgica del Sur SRL',  45, 'Av. Corrientes 1100, CABA',     '1150607080'),
    ('Ferreteria Industrial SA', 38, 'Mitre 2450, Quilmes',           '1145231190'),
    ('Talleres Bermudez',        52, 'Calle 12 Nro 340, Avellaneda',  '1163728451'),
    ('Herramientas Rivas',       29, 'San Martin 780, Lanus',         '1148902233'),
    ('Distribuidora Norte',      61, 'Ruta 8 Km 32, Malvinas Arg.',   '1159887412');

INSERT INTO productos (nombre, categoria, precio, stock) VALUES
    ('Disco de corte 115mm',        'herramienta',  3000.00, 1000),
    ('Mecha helicoidal HSS 10mm',   'herramienta',  4500.50,  350),
    ('Inserto de torneado CNMG',    'inserto',     12800.00,  120),
    ('Sierra copa bimetalica 32mm', 'herramienta',  9750.00,   80),
    ('Paño abrasivo grano 120',     'abrasivo',     1250.75,  600);

INSERT INTO ventas (id_cliente, id_producto, cantidad, fecha, responsable, estado) VALUES
    (1, 1, 100, '2026-05-13', 'Juan Gomez',      'entregado'),
    (2, 1,  50, '2026-05-20', 'Carlos Duarte',   'entregado'),
    (3, 3,  10, '2026-05-27', 'Maria Fernandez', 'entregado'),
    (2, 3,  25, '2026-06-02', 'Maria Fernandez', 'entregado'),
    (1, 5,  80, '2026-06-10', 'Juan Gomez',      'entregado'),
    (3, 5, 200, '2026-06-18', 'Juan Gomez',      'enviado'),
    (5, 2,  30, '2026-06-25', 'Carlos Duarte',   'enviado'),
    (4, 2,  40, '2026-07-09', 'Carlos Duarte',   'entregado'),
    (2, 5, 150, '2026-07-15', 'Maria Fernandez', 'enviado'),
    (4, 3,   8, '2026-07-22', 'Juan Gomez',      'procesando'),
    (1, 3,  15, '2026-08-05', 'Maria Fernandez', 'procesando'),
    (5, 4,  10, '2026-08-21', 'Maria Fernandez', 'pendiente'),
    (3, 1,  60, '2026-08-28', 'Carlos Duarte',   'pendiente');

COMMIT;


-- 4) CONSULTA DE ANÁLISIS AVANZADO

-- CTE 1: ventas_mensuales
-- Normaliza la fecha al primer día del mes y suma las ventas
-- (cantidad * precio) por mes y categoría. Deja todo a nivel mes/categoría.
WITH ventas_mensuales AS (
    SELECT
        DATE_TRUNC('month', v.fecha)::date AS mes,
        p.categoria,
        SUM(v.cantidad * p.precio)         AS monto
    FROM ventas v
    JOIN productos p ON v.id_producto = p.id_producto
    GROUP BY DATE_TRUNC('month', v.fecha), p.categoria
),

-- CTE 2: metricas_ventana
-- ranking:            posición de cada categoría dentro de su mes (mayor venta = 1).
-- monto_acumulado:    running total de cada categoría a lo largo de los meses.
-- promedio_categoria: promedio histórico mensual de la categoría (para la comparativa).
metricas_ventana AS (
    SELECT
        mes,
        categoria,
        monto,
        RANK() OVER (PARTITION BY mes ORDER BY monto DESC)  AS ranking,
        SUM(monto) OVER (PARTITION BY categoria ORDER BY mes) AS monto_acumulado,
        AVG(monto) OVER (PARTITION BY categoria)              AS promedio_categoria
    FROM ventas_mensuales
)

-- SELECT final: reporte con las cinco columnas pedidas.
-- El CASE compara la venta del mes contra el promedio de su categoría
-- y devuelve únicamente 'Exitoso' o 'Bajo el promedio'.
SELECT
    mes,
    categoria,
    monto,
    ranking,
    monto_acumulado,
    CASE
        WHEN monto >= promedio_categoria THEN 'Exitoso'
        ELSE 'Bajo el promedio'
    END AS desempenio
FROM metricas_ventana
ORDER BY mes, ranking;