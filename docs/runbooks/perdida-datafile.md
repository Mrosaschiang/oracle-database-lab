# Runbook · Pérdida de un datafile (no SYSTEM/UNDO) con la base en ARCHIVELOG

**Cuándo usarlo:** el alert log o una consulta muestra `ORA-01110` / `ORA-01116` / `ORA-27041` (no se puede abrir el
archivo), o una PDB no abre con `ORA-01113` / `ORA-01157`. Requisitos: base en **ARCHIVELOG**, una copia RMAN del
tablespace afectado y todo el redo archivado desde esa copia.

**Objetivo:** RPO = 0 (nada confirmado se pierde). RTO = minutos (solo se restaura un archivo, el resto sigue en servicio).

## 1. Diagnosticar (sin tocar nada)
```bash
bash scripts/ops/sysdba.sh <(echo "SELECT file#, name, status, error FROM v\$recover_file JOIN v\$datafile USING (file#);")
docker exec oralab-26ai tail -50 /opt/oracle/diag/rdbms/free/FREE/trace/alert_FREE.log
```
Anota el número de archivo, el tablespace y la PDB. Comprueba que la base está en ARCHIVELOG (`ARCHIVE LOG LIST`).

## 2. Aislar el daño
Desde la PDB: `ALTER DATABASE DATAFILE <n> OFFLINE;` (o `ALTER TABLESPACE <ts> OFFLINE IMMEDIATE`).
El resto de tablespaces y PDB siguen abiertos.

## 3. Restaurar y recuperar con RMAN (dentro del contenedor)
```
docker exec -it oralab-26ai rman target /
RMAN> RESTORE DATAFILE <n>;
RMAN> RECOVER DATAFILE <n>;      # aplica redo archivado + online hasta el último COMMIT
RMAN> ALTER DATABASE DATAFILE <n> ONLINE;   # o: ALTER PLUGGABLE DATABASE FREEPDB1 OPEN;
```

## 4. Verificar
* `SELECT * FROM v$recover_file;` → sin filas.
* El dato confirmado después de la copia (fila 104 en el simulacro) sigue ahí → **RPO 0**.
* `bash scripts/ops/ro.sh scripts/lab5/15-healthcheck.sql` → sin errores nuevos.

## 5. Después
* Hacer una copia RMAN nueva (`BACKUP TABLESPACE <ts>;`) y anotar RTO/RPO medidos.
* Abrir un postmortem sin culpables: causa, detección, tiempos y una acción de mejora.

**No hacer:** restaurar la base completa (RTO de minutos a horas y pérdida de lo confirmado tras la copia),
ni `RESETLOGS`, ni borrar redo archivado antes de tener una copia nueva.
