-- scripts/lab5/02-reto-ux-cli-email.sql — reto de la Parte C: altura medida de UX_CLI_EMAIL frente a PK_CLIENTE
WHENEVER SQLERROR EXIT FAILURE
ALTER SESSION SET CONTAINER = FREEPDB1;
SET LINESIZE 200 PAGESIZE 100
COLUMN name FORMAT A14
PROMPT ===== UX_CLI_EMAIL (100 000 entradas, claves que llegan desordenadas) =====
ANALYZE INDEX tiendasur.ux_cli_email VALIDATE STRUCTURE;
SELECT name, height, lf_blks, br_blks, lf_rows, br_rows, ROUND(lf_rows/lf_blks) AS entradas_por_hoja,
       ROUND(br_rows/NULLIF(br_blks,0)) AS fo_medio, pct_used FROM index_stats;
PROMPT ===== PK_CLIENTE (100 000 entradas, claves que llegan en orden ascendente) =====
ANALYZE INDEX tiendasur.pk_cliente VALIDATE STRUCTURE;
SELECT name, height, lf_blks, br_blks, lf_rows, br_rows, ROUND(lf_rows/lf_blks) AS entradas_por_hoja,
       ROUND(br_rows/NULLIF(br_blks,0)) AS fo_medio, pct_used FROM index_stats;
EXIT
