# Lab 4 — Oracle DBA Workflow I · Respuestas

Evidencias en `docs/bitacora/lab4/evidencia/` (se cita el sufijo del archivo: `*_00-backup-lab3`, `*_06-arranque-por-etapas`, etc.).

## Respaldo

**1. ¿Por qué la copia de la Parte B es consistente? ¿Qué pasaría con la base abierta?**
Se tomó tras `SHUTDOWN IMMEDIATE` y `docker stop` (`*_00-backup-lab3`: "Database closed / dismounted / ORACLE instance shut down"). El cierre hace checkpoint: todos los datafiles, control files y redo quedan en el mismo SCN y sin transacciones a medias, así que la copia arranca con un simple STARTUP sin recuperación. Con la base abierta, `tar` copiaría archivos que DBWn sigue escribiendo, cada uno en un momento distinto: la copia sería inconsistente (o directamente corrupta) y necesitaría recuperación con redo, que esta copia no guarda.

**2. ¿Para qué sirven `manifiesto.txt` y `SHA256SUMS`? ¿Qué comprueba `restaurar-estado.sh` antes de tocar nada?**
`manifiesto.txt` describe la copia: etiqueta, fecha, contenedor, volumen, imagen, commit de Git, tipo de copia y archivos fuera del volumen (en mi caso `archivos_fuera_del_volumen=0`). `SHA256SUMS` guarda la huella de cada archivo para detectar cualquier cambio o corrupción (`sha256sum --check` dio OK en los 4 archivos). `restaurar-estado.sh` primero comprueba que Docker responde, después verifica la integridad SHA-256 y muestra el manifiesto, y pide escribir el nombre del volumen para confirmar. Solo entonces para la base y sobrescribe el volumen.

**3. RPO y RTO con mis datos.**
RPO (cuántos datos puedo perder): todo lo posterior al momento de la copia, el 2026-10-27 a las 21:17 UTC (SCN 4147358 en el inventario). Si la base se perdiera ahora, volvería a ese punto. RTO (cuánto tardo en volver a dar servicio): la copia tardó unos 3 minutos (parada, `tar` de 4888 MB comprimidos a 523 MB y arranque a healthy en 10 s). La restauración hace el camino inverso con un archivo de 523 MB, así que el RTO estimado es de unos pocos minutos.

## Diagnóstico y correcciones

**4. ¿Dónde creó Oracle los datafiles de V000 y por qué? ¿Qué parámetro lo habría evitado?**
En `$ORACLE_HOME/dbs` (`*_01-diagnostico`: `/opt/oracle/product/26ai/dbhomeFree/dbs/academia01.dbf`, etc.), porque V000 usó una ruta relativa (`'academia01.dbf'`) y `db_create_file_dest` estaba vacío ("sin OMF"). Con `DB_CREATE_FILE_DEST=/opt/oracle/oradata` (OMF) o una ruta absoluta en V000 se habrían creado dentro del volumen. En mi imagen `dbs` es un enlace simbólico a `/opt/oracle/oradata/dbconfig/FREE/dbs` (`*_00-dbs-enlace`), así que físicamente estaban dentro del volumen, pero en una carpeta no estándar y dependiendo de un enlace que puede cambiar con la imagen.

**5. ¿Por qué `ALTER TABLESPACE ... RENAME DATAFILE` no basta para mover un archivo?**
Solo cambia la ruta que guarda el control file; no copia ni mueve nada en disco. Por eso `03-reubicar-datafiles.sh` pone el tablespace OFFLINE, copia el archivo con `cp -p`, hace el RENAME, lo vuelve a poner ONLINE (Oracle valida la cabecera) y solo entonces borra el original.

**6. ¿Por qué no se edita V000 y se crea V003? ¿Por qué invalidar una contraseña es mejor que borrarla?**
Una migración aplicada es historia: editarla haría que el repositorio ya no describa lo que se ejecutó en la base, y cualquier entorno nuevo divergiría. Los cambios se hacen con migraciones nuevas. Borrar la contraseña del archivo no sirve porque sigue en el historial de Git; lo que protege es invalidarla. V003 convierte las cuentas `ADMIN_*` en cuentas de solo esquema (`NO AUTHENTICATION`): mi evidencia muestra `NONE` en las 5, y la contraseña de V000 da `ORA-01017` (`*_03-password-v000-revocada`).

**7. ¿Qué demuestra la prueba de persistencia y por qué va después de reubicar?**
Demuestra que toda la base vive en el volumen: borré el contenedor, lo recreé con 05 v2 y aparecieron los mismos 5 tablespaces en `FREE/FREEPDB1`, las mismas tablas (3/3/2/3/3) y solo el puerto 1521 (`*_03-prueba-persistencia`). Se ejecuta después de reubicar porque, si algún datafile estuviera fuera del volumen, `docker rm` lo borraría junto con la capa del contenedor. Por eso el bloque solo la lanzaba si quedaban 0 datafiles fuera de su sitio.

## Instancia y arranque

**8. Tres datos de la instancia y tres de la base (mis evidencias).**
Instancia (`*_05-instancia-y-base`, `*_05-instancia-so`): `INSTANCE_NAME=FREE` con `STARTUP_TIME` 2026-10-27 21:25:45, `HOST_NAME=0374ce7d4e7f` (el ID del contenedor recreado) y 63 procesos de background con ~2 GiB de memoria. Base de datos: `DBID=1509902213`, `CREATED=2026-07-05` y `LOG_MODE=ARCHIVELOG`, con 16 datafiles (3984 MB). La instancia era nueva tras recrear el contenedor; la base era la misma.

**9. ¿Qué lee Oracle en NOMOUNT, MOUNT y OPEN? Relación con ORA-01507 y ORA-01219.**
NOMOUNT: lee el SPFILE, reserva la SGA y arranca procesos; `v$parameter` responde pero `v$database` da `ORA-01507` porque el control file aún no está abierto. MOUNT: abre los control files y conoce la estructura (`v$database` y `v$datafile` responden), pero `dba_tables` da `ORA-01219` porque el diccionario está en el tablespace SYSTEM, que aún no está abierto. OPEN: abre datafiles y redo; ya está todo accesible (`*_06-arranque-por-etapas`).

**10. ¿Por qué FREEPDB1 se abre sola tras `ALTER DATABASE OPEN`? ¿Y si no lo hiciera?**
Porque tiene el estado guardado con `ALTER PLUGGABLE DATABASE ... SAVE STATE`: al abrir el CDB, Oracle devuelve cada PDB al estado guardado. Si se quedara en MOUNTED (y las aplicaciones recibieran `ORA-01109`), haría `ALTER PLUGGABLE DATABASE FREEPDB1 OPEN;` y después `ALTER PLUGGABLE DATABASE FREEPDB1 SAVE STATE;`.

**11. ORA-00800 y ORA-20013: ¿alerta real o ruido conocido?**
Ruido conocido de contenedores. `ORA-00800 [Set Priority Failed] [VKTM]/[LGWR]`: Oracle intenta subir la prioridad de esos procesos y el contenedor no tiene permiso; la base funciona igual. `ORA-20013 DBMS_QOPATCH`: el inventario de parches no se puede leer en la imagen. Además apareció una vez `ORA-27300/27301/27302/27303 chdir() failed`: lo investigué; es un aviso del sistema operativo (un proceso hereda un directorio de trabajo que no existe en el contenedor) durante la parada y el arranque lanzados con `docker exec`. La instancia abrió correctamente y no se repite en uso normal, así que lo clasifico como no crítico.

## Parámetros

**12. `v$parameter` frente a `v$spparameter` (db_files).**
`v$parameter` muestra el valor en memoria de la instancia actual; `v$spparameter`, lo escrito en el SPFILE para el próximo arranque. Con `SCOPE=SPFILE` puse `db_files=300`: el SPFILE lo tenía (`isspecified=TRUE`) pero en memoria seguía el valor anterior. Tras `ALTER SYSTEM RESET db_files SCOPE=SPFILE` la línea desapareció (`db_files_spfile=FALSE` en `*_10-verificacion-final`).

**13. ¿Qué hace `SCOPE=BOTH` y cuál es el SCOPE por defecto con SPFILE?**
Cambia el valor en memoria y en el SPFILE a la vez: se aplica ya y sobrevive al reinicio (mi `open_cursors=500` con comentario "Lab4: prueba SCOPE=BOTH"). Si la instancia arrancó con SPFILE, el SCOPE por defecto es BOTH.

**14. ¿Por qué PROCESSES rechaza el cambio en memoria?**
`PROCESSES` dimensiona estructuras de la SGA que se reservan al arrancar, así que en la práctica solo cambia con reinicio. Mi intento de `processes=250 SCOPE=MEMORY` devolvió `ORA-02097` y `ORA-02095` (`*_07-parametros-cambios`). La forma correcta es `SCOPE=SPFILE` y reiniciar.

**15. ¿Para qué versionar el PFILE? ¿Qué es "configuration drift"?**
El PFILE es la versión en texto del SPFILE: al versionarlo queda registrada la configuración y se puede comparar con Git o usar para arrancar si el SPFILE se estropea. "Configuration drift" es cuando la configuración real de un servidor se va separando poco a poco de la documentada por cambios manuales sin registrar. Mi evidencia tiene dos PFILE: 32 líneas desde el SPFILE y 122 desde memoria; la diferencia son valores derivados o por defecto.

## Memoria y procesos

**16. Modelo de gestión de memoria (tres parámetros).**
ASMM (gestión automática de la memoria compartida): `memory_target=0` (no hay AMM), `sga_target=1536M` (Oracle reparte la SGA entre sus componentes) y `pga_aggregate_target=512M` (la PGA se gestiona aparte, con límite `pga_aggregate_limit=2G`). Además `db_cache_size=0` y `shared_pool_size=0`: sin mínimos fijados, Oracle decide (1088 MB de buffer cache y 400 MB de shared pool, en gránulos de 16 MB).

**17. Cifras del experimento de caché.**
`ACA_ESTUDIANTES` ocupa 244 bloques. Ronda 1, con la caché vacía: 463 lecturas lógicas y 260 físicas (los bloques se leyeron del disco). Ronda 2: 247 lógicas y 0 físicas (todo desde la Buffer Cache). Tasa de acierto = 1 − físicas/lógicas: 43,8 % en la ronda 1 y 100 % en la ronda 2. Al final, 245 bloques de la tabla estaban en `v$bh`.

**18. ¿Por qué no se suma el RSS de los procesos?**
Porque la SGA es memoria compartida: cada proceso la tiene mapeada y su RSS la cuenta, así que sumar los RSS contaría la SGA decenas de veces. La memoria real se ve con `v$sga`/`v$pgastat` o con la memoria del contenedor (`docker stats`: ~2 GiB).

**19. SPID de LGWR frente al PID de `/proc`. ¿Por qué `docker top` muestra otro número?**
`v$process` dio `SPID=913` para LGWR, y dentro del contenedor el proceso con PID 913 es `db_lgwr_FREE` (`*_09-procesos-so`): el SPID es el PID del sistema operativo. `docker top` muestra otro número porque el contenedor tiene su propio espacio de nombres de PID: Docker enseña el PID visto desde el host (la máquina virtual de Docker Desktop), no el de dentro del contenedor.

**20. PMON y SMON con un ejemplo.**
PMON (process monitor) limpia lo que deja un proceso que muere: si se corta la conexión de un usuario a mitad de una transacción, deshace sus cambios y libera sus bloqueos. SMON (system monitor) se encarga de la base: hace la recuperación de instancia al abrir tras un `SHUTDOWN ABORT` o una caída, y limpia segmentos temporales.

## Seguridad y trabajo profesional

**21. ¿Por qué C##OPS_RO y no SYSTEM? ¿Qué no puede hacer?**
Mínimo privilegio: para observar basta con leer vistas, y SYSTEM puede modificar cualquier cosa, así que un error o una credencial filtrada tendría mucho más impacto. `C##OPS_RO` es común (existe en CDB$ROOT y en FREEPDB1, `COM=YES`) y solo tiene permisos de lectura y sesión: no puede crear ni modificar objetos, usuarios ni parámetros, ni parar la instancia.

**22. ¿Qué dos vías de exposición de contraseñas corrige este laboratorio?**
Primera: contraseñas literales en el repositorio (V000), que se invalidan con V003. Segunda: la contraseña de SYS en la línea de comandos (`sys/<contraseña>@...` en el 08 del Lab 3, visible con `ps` y en el historial), que el 08 v2 sustituye por `/ as sysdba`. Además, 05 v2 no pasa contraseñas al contenedor cuando reutiliza el volumen, y `ro.sh` envía la de C##OPS_RO por la entrada estándar.

## Preguntas tipo examen

| Pregunta | Respuesta | Justificación |
|---|---|---|
| P1 | A, D | Tras SHUTDOWN IMMEDIATE todo queda en el mismo SCN: copia consistente que abre con STARTUP sin recuperación. |
| P2 | B | En Standard Edition no hay MOVE DATAFILE online: OFFLINE, copiar, RENAME y ONLINE. |
| P3 | A, C | STARTUP_TIME cambia en cada arranque; CREATED es la fecha de creación de la base (DBID no cambia al recrear el contenedor). |
| P4 | A, C | En NOMOUNT ya hay SPFILE en memoria (v$parameter) y se puede recrear el control file; el resto necesita MOUNT u OPEN. |
| P5 | B | El modo ARCHIVELOG se cambia en MOUNT. |
| P6 | B | Con SPFILE el SCOPE por defecto es BOTH. |
| P7 | C | PROCESSES es de instancia: desde una PDB da ORA-65040 (lo vi en mi evidencia 07). |
| P8 | A, C | Arrancar con un PFILE bueno y regenerar el SPFILE desde él. |
| P9 | B | Con SGA_TARGET>0 actúa ASMM y DB_CACHE_SIZE pasa a ser un mínimo. |
| P10 | A, D | La sort area y la memoria de sesión en servidor dedicado están en la PGA; el resto es SGA. |
| P11 | C | El COMMIT espera a que LGWR escriba el redo en disco. |
| P12 | B, D | PMON y SMON son obligatorios; ARC0, RECO y CJQ0 dependen de la configuración. |
