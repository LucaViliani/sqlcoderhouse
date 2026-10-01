-- =====================================================
-- CONSULTA 1: Rentabilidad por categoría
-- Problema de negocio: identificar qué categorías generan más
-- ingresos para decidir dónde enfocar inversión y stock.
-- Umbral definido: $56.000 de ingreso total (descarta las
-- categorías de bajo aporte).
-- =====================================================
SELECT
    cat.nombre_categoria,
    SUM(v.cantidad)                AS unidades_vendidas,
    SUM(v.cantidad * p.precio)     AS ingreso_total
FROM ventas v
JOIN productos p   ON v.id_producto  = p.id_producto
JOIN categorias cat ON p.id_categoria = cat.id_categoria
GROUP BY cat.nombre_categoria
HAVING SUM(v.cantidad * p.precio) > 56000
ORDER BY ingreso_total DESC;

-- =====================================================
-- CONSULTA 2: Clientes sin compras
-- Problema de negocio: detectar clientes registrados que nunca
-- compraron, para armar campañas de activación.
-- =====================================================
SELECT
    c.nombre_cliente,
    c.email,
    COALESCE(COUNT(v.id_venta), 0) AS compras_realizadas
FROM clientes c
LEFT JOIN ventas v ON c.id_cliente = v.id_cliente
GROUP BY c.nombre_cliente, c.email
HAVING COUNT(v.id_venta) = 0;

-- =====================================================
-- CONSULTA 3: Top de compras por cliente
-- Problema de negocio: conocer el producto favorito de cada
-- cliente y cuándo fue su última transacción, para
-- personalizar ofertas y detectar clientes inactivos.
-- Desempate: más unidades, luego compra más reciente.
-- =====================================================
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
            ORDER BY cp.veces_comprado DESC, cp.unidades DESC, cp.ultima_compra_producto DESC
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