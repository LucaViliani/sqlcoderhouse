-- =====================================================================
-- pre-entrega-modulo4.sql
-- Consultas multicapa para análisis de negocio (PostgreSQL)
--
-- El script es autocontenido: crea el esquema (DDL), carga datos de
-- prueba (seed) y ejecuta las 3 consultas. Se puede correr completo
-- sobre una base vacía y volver a correr sin errores.
--
-- Paso previo (ejecutar por separado y luego conectarse a la base):
--   CREATE DATABASE clase_sql;
-- =====================================================================


-- =====================================================================
-- 1) ESQUEMA (DDL)
-- Única definición de tablas del repositorio. Las consultas de abajo
-- usan exactamente estos nombres de tablas y columnas.
-- Se borran primero para que el script sea reejecutable.
-- =====================================================================
DROP TABLE IF EXISTS ventas;
DROP TABLE IF EXISTS clientes;
DROP TABLE IF EXISTS productos;
DROP TABLE IF EXISTS categorias;

CREATE TABLE categorias (
    id_categoria     SERIAL       PRIMARY KEY,
    nombre_categoria VARCHAR(50)  NOT NULL
);

CREATE TABLE productos (
    id_producto      SERIAL        PRIMARY KEY,
    nombre_producto  VARCHAR(80)   NOT NULL,
    id_categoria     INT           NOT NULL REFERENCES categorias(id_categoria),
    precio           NUMERIC(10,2) NOT NULL CHECK (precio > 0)
);

CREATE TABLE clientes (
    id_cliente       SERIAL       PRIMARY KEY,
    nombre_cliente   VARCHAR(80)  NOT NULL,
    email            VARCHAR(100),               -- opcional: puede ser NULL
    fecha_registro   DATE         NOT NULL
);

CREATE TABLE ventas (
    id_venta         SERIAL PRIMARY KEY,
    id_cliente       INT    NOT NULL REFERENCES clientes(id_cliente),
    id_producto      INT    NOT NULL REFERENCES productos(id_producto),
    cantidad         INT    NOT NULL CHECK (cantidad > 0),
    fecha_venta      DATE   NOT NULL
);


-- =====================================================================
-- 2) DATOS DE PRUEBA (SEED)
-- Pensados para que cada consulta tenga casos que la pongan a prueba:
--   - Deportes queda por debajo del umbral de la Consulta 1.
--   - Elba y Roberto no compraron nunca (Consulta 2); Roberto además
--     no tiene email, para probar el manejo de NULL.
--   - En la Consulta 3 hay compras repetidas y los dos tipos de empate
--     (ver el comentario de esa consulta).
-- =====================================================================
INSERT INTO categorias (nombre_categoria) VALUES
    ('Electrónica'),        -- 1
    ('Hogar'),              -- 2
    ('Deportes'),           -- 3
    ('Marketing Digital');  -- 4

INSERT INTO productos (nombre_producto, id_categoria, precio) VALUES
    ('Auriculares BT',    1,  15000.00),  -- 1
    ('Notebook 14"',      1, 480000.00),  -- 2
    ('Cafetera',          2,  32000.00),  -- 3
    ('Set de sábanas',    2,  21000.00),  -- 4
    ('Pelota de fútbol',  3,   9000.00),  -- 5
    ('Mancuernas 5kg',    3,  14000.00),  -- 6
    ('Curso Ads Básico',  4,  25000.00),  -- 7
    ('Consultoría SEO',   4,  60000.00);  -- 8

INSERT INTO clientes (nombre_cliente, email, fecha_registro) VALUES
    ('Juan Fleming',        'juan.fleming@mail.com',    '2024-01-10'),  -- 1
    ('Mariela Eratóstenes', 'mariela.era@mail.com',     '2024-02-15'),  -- 2
    ('Cristian Newton',     'cristian.newton@mail.com', '2024-03-02'),  -- 3
    ('Fernando Fernández',  'fer.fernandez@mail.com',   '2024-03-20'),  -- 4
    ('Silvana Ríos',        'silvana.rios@mail.com',    '2024-05-11'),  -- 5
    ('Elba Jiménez',        'elba.jimenez@mail.com',    '2024-06-01'),  -- 6 sin compras
    ('Roberto Paz',         NULL,                       '2024-07-05');  -- 7 sin compras ni email

INSERT INTO ventas (id_cliente, id_producto, cantidad, fecha_venta) VALUES
    (1, 1, 2, '2024-04-01'),
    (1, 2, 1, '2024-05-14'),
    (1, 1, 1, '2024-07-03'),  -- Juan repite Auriculares
    (2, 3, 1, '2024-04-20'),
    (2, 7, 1, '2024-06-02'),
    (2, 3, 1, '2024-08-11'),  -- Mariela repite Cafetera
    (3, 5, 3, '2024-04-25'),
    (3, 6, 2, '2024-06-10'),  -- Cristian: empate en veces, desempata por unidades
    (4, 8, 1, '2024-05-30'),
    (4, 7, 1, '2024-07-18'),  -- Fernando: empate en veces y unidades, desempata por fecha
    (5, 4, 1, '2024-06-15');


-- =====================================================================
-- CONSULTA 1: Rentabilidad por categoría
-- Problema de negocio: identificar qué categorías generan más
-- ingresos para decidir dónde enfocar inversión y stock.
-- Umbral definido: $56.000 de ingreso total (descarta las
-- categorías de bajo aporte). Une 3 tablas: ventas, productos y
-- categorias.
--
-- Salida esperada con los datos de prueba:
--  nombre_categoria  | unidades_vendidas | ingreso_total
-- -------------------+-------------------+---------------
--  Electrónica       |                 4 |     525000.00
--  Marketing Digital |                 3 |     110000.00
--  Hogar             |                 3 |      85000.00
-- (Deportes queda afuera: $55.000 < umbral)
-- =====================================================================
SELECT
    cat.nombre_categoria,
    SUM(v.cantidad)             AS unidades_vendidas,
    SUM(v.cantidad * p.precio)  AS ingreso_total
FROM ventas v
JOIN productos p    ON v.id_producto  = p.id_producto
JOIN categorias cat ON p.id_categoria = cat.id_categoria
GROUP BY cat.nombre_categoria
HAVING SUM(v.cantidad * p.precio) > 56000
ORDER BY ingreso_total DESC;


-- =====================================================================
-- CONSULTA 2: Clientes sin compras
-- Problema de negocio: detectar clientes registrados que nunca
-- compraron, para armar campañas de activación.
-- Manejo de nulos: el LEFT JOIN deja en NULL las columnas de ventas
-- cuando el cliente no tiene transacciones. COALESCE reemplaza:
--   - la fecha de última compra (NULL) por 'Sin compras'
--   - el email (columna opcional, puede ser NULL) por 'Sin email'
-- COUNT(v.id_venta) ya devuelve 0 en esos casos, por eso no lleva
-- COALESCE.
--
-- Salida esperada con los datos de prueba:
--  nombre_cliente | email                 | compras_realizadas | ultima_compra
-- ----------------+-----------------------+--------------------+---------------
--  Elba Jiménez   | elba.jimenez@mail.com |                  0 | Sin compras
--  Roberto Paz    | Sin email             |                  0 | Sin compras
-- =====================================================================
SELECT
    c.nombre_cliente,
    COALESCE(c.email, 'Sin email')                                 AS email,
    COUNT(v.id_venta)                                              AS compras_realizadas,
    COALESCE(TO_CHAR(MAX(v.fecha_venta), 'YYYY-MM-DD'), 'Sin compras') AS ultima_compra
FROM clientes c
LEFT JOIN ventas v ON c.id_cliente = v.id_cliente
GROUP BY c.id_cliente, c.nombre_cliente, c.email
HAVING COUNT(v.id_venta) = 0
ORDER BY c.nombre_cliente;


-- =====================================================================
-- CONSULTA 3: Top de compras por cliente
-- Problema de negocio: conocer el producto favorito de cada
-- cliente y cuándo fue su última transacción, para
-- personalizar ofertas y detectar clientes inactivos.
-- Criterio: gana el producto comprado más veces.
-- Desempate: 1) más unidades, 2) compra más reciente de ese producto.
-- ultima_transaccion es la última compra del cliente (de cualquier
-- producto).
--
-- Casos de desempate cubiertos por los datos de prueba:
--   - Cristian: Pelota y Mancuernas, 1 vez cada uno -> gana Pelota
--     por unidades (3 contra 2).
--   - Fernando: Consultoría SEO y Curso Ads, 1 vez y 1 unidad cada uno
--     -> gana Curso Ads por ser la compra más reciente.
--
-- Salida esperada con los datos de prueba:
--  nombre_cliente      | producto_mas_comprado | veces_comprado | ultima_transaccion
-- ---------------------+-----------------------+----------------+--------------------
--  Cristian Newton     | Pelota de fútbol      |              1 | 2024-06-10
--  Fernando Fernández  | Curso Ads Básico      |              1 | 2024-07-18
--  Juan Fleming        | Auriculares BT        |              2 | 2024-07-03
--  Mariela Eratóstenes | Cafetera              |              2 | 2024-08-11
--  Silvana Ríos        | Set de sábanas        |              1 | 2024-06-15
-- =====================================================================
WITH compras_por_producto AS (
    SELECT
        c.id_cliente,
        c.nombre_cliente,
        p.nombre_producto,
        COUNT(v.id_venta)   AS veces_comprado,
        SUM(v.cantidad)     AS unidades,
        MAX(v.fecha_venta)  AS ultima_compra_producto
    FROM clientes c
    JOIN ventas v    ON c.id_cliente  = v.id_cliente
    JOIN productos p ON v.id_producto = p.id_producto
    GROUP BY c.id_cliente, c.nombre_cliente, p.nombre_producto
),
ranking AS (
    SELECT
        cp.*,
        ROW_NUMBER() OVER (
            PARTITION BY cp.id_cliente
            ORDER BY cp.veces_comprado DESC,
                     cp.unidades DESC,
                     cp.ultima_compra_producto DESC
        ) AS posicion,
        MAX(cp.ultima_compra_producto) OVER (PARTITION BY cp.id_cliente) AS ultima_transaccion
    FROM compras_por_producto cp
)
SELECT
    r.nombre_cliente,
    r.nombre_producto AS producto_mas_comprado,
    r.veces_comprado,
    r.ultima_transaccion
FROM ranking r
WHERE r.posicion = 1
ORDER BY r.nombre_cliente;
