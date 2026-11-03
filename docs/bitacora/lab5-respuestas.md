# Lab 5 · Oracle DBA Workflow II — Respuestas

**Estudiante:** Mateo Rosas Chiang · **GitHub:** Mrosaschiang · **Issue:** #8 · **Rama:** `chore/8-oracle-dba-workflow-ii`
**Base:** Oracle AI Database 26ai Free 23.26.3 (contenedor `oralab-26ai`, WSL Ubuntu 24.04) · **Ejecución:** 3-nov-2026, 20:27–20:44 UTC
**Verificación final:** `16-verificacion-final.sh` → **RESULTADO: TODO OK** (evidencia `20261103T204413Z_16-verificacion-final.script.log`)

Todas las cifras son de mi ejecución; la ruta de evidencia es `docs/bitacora/lab5/evidencia/`.

---

## 1. Preguntas de comprobación

### Punto de partida y banco de medida (A, B)

**1. Paso 6 de la copia lab4-final frente a lab3-final.**
En la copia `lab3-final` el paso 6 listaba los cinco datafiles de negocio (academia, clínica, retail, logística y fintech) fuera del volumen; en mi copia `lab4-final` (`20261103T202726Z_00-backup-lab4.script.log`) el paso 6 dice *"ninguno: el volumen contiene toda la base de datos"* y el paso 3 marca los 26 archivos como `dentro`. Demuestra que la reubicación del Lab 4 (Parte C) funcionó: la copia del volumen (605 MB) es completa y autosuficiente, sin archivos que haya que copiar aparte.

**2. Factor de bloqueo.** Con `01-perfil-tiendasur.script.log`: CLIENTE r = 100 000, b = 1517 → bfr = 100 000 / 1517 ≈ **66** filas/bloque (R = 102 bytes); PEDIDO r = 1 000 000, b = 5320 → bfr = **188** (R = 32 bytes). Comprobación: ⌈1 000 000 / 188⌉ = 5320 ✓. PEDIDO cabe casi el triple porque su fila es ~3,2 veces más corta (32 frente a 102 bytes: CLIENTE lleva email, DNI, nombre, apellidos, teléfono…). El bfr depende del tamaño de fila, no de la tabla.

**3. Por qué se mide la segunda ejecución.** La primera puede incluir trabajo único: análisis duro (hard parse), lecturas físicas para traer los bloques a la caché y la limpieza diferida de bloques (delayed block cleanout). La segunda mide el estado estable "en caliente" y es comparable entre alternativas; por eso en todas mis medidas `físicas = 0` (p. ej. `prueba_pk … lecturas lógicas = 4 físicas = 0`).

### Anatomía y tipos de índice (C, D)

**4. IX_PED_CLIENTE** (`02-anatomia-indice.script.log`): altura **3**, **2216** hojas, 6 ramas, fan-out real (2216 + 6 − 1) / 6 = **370**, máximo 8028 / 14,8 = **543**, 451 entradas por hoja (90 %). Con mil millones de filas: 2 208 969 hojas → 1 + ⌈log₅₄₃ 2 208 969⌉ = 1 + 3 = **altura 4** (5 lecturas para una fila).

**Reto C.** Cálculo a mano para UX_CLI_EMAIL: 30 bytes/entrada → ~7196 / 30 ≈ 240 entradas por hoja → ≈ 417 hojas; con fo = 543 saldría altura 2. **Medido** (`02-reto-ux-cli-email.script.log`): altura **3**, 501 hojas, 3 ramas, 200 entradas por hoja, fo medio 167. La hipótesis falla porque la clave del email es mucho más larga que un NUMBER: las entradas de rama también lo son y caben menos por bloque, así que 501 hojas ya no caben bajo una sola raíz. PK_CLIENTE: altura 2, 187 hojas, 535 entradas/hoja, PCT_USED 100.
Mapas: PK_CLIENTE `[####…#-]` con 99,6 % de ocupación — sus claves llegaron en orden ascendente (divisiones 90/10, hojas llenas; solo la última está a medias). UX_CLI_EMAIL `[====…=]` con 89,6 %: sus claves no llegan en orden (`cliente10…` < `cliente2…` como texto) y su llenado es el PCTFREE 10 de la creación. Mismo número de entradas, distinto orden de llegada.

**5. ROWID en la hoja de PK_CLIENTE.** Primera entrada: `row#0 … data:(6): 00 00 03 1b 00 00`, clave `c1 02` (= 1). Los 6 bytes son 4 de bloque (`0x0000031B` = **795**) y 2 de ranura (`0x0000` = **fila 0**); `DBMS_ROWID` lo confirma: cliente 1 → bloque 795, ranura 0. No aparece el número de archivo porque TBS_TIENDASUR es **BIGFILE** (un único datafile: el archivo es implícito y el bloque usa 32 bits) y el índice guarda un ROWID restringido: el objeto y el tablespace ya los conoce por el segmento.

**6. Tres pruebas de la Parte D** (`03-tipos-indice.script.log`):
- **Q7 compuesto y cubriente:** `ix_ped_cliente` 15 lecturas (con SORT ORDER BY) → `(id_cliente, fecha)` 7 (el índice ya devuelve las filas ordenadas, sin SORT) → cubriente 3 (ni siquiera va a la tabla).
- **Q14 bitmap:** sin bitmaps 4073 lecturas (FULL) → con 4 bitmaps combinados por `BITMAP AND` 528. Además, BX_VH_REGION ocupa 114 hojas frente a 1954 del B-tree equivalente.
- **Q15 heap / IOT / hash:** montículo + PK 4 lecturas, IOT 3 (la tabla es el índice), clúster hash 2 (la clave da la dirección del bloque); pero la limpieza por rango en el hash lee **2770** (no sirve para rangos).
- (Extra) **Q13 único:** 1486 → 3 lecturas, y además `ORA-00001` impide el DNI duplicado: la regla la garantiza la base.

### Agrupamiento, equilibrio y sargabilidad (E, F)

**7. Clustering factor** (`04-agrupamiento-equilibrio.script.log`): IX_PED_FECHA CF = **5220** ≈ 5320 bloques (BUENO) porque los pedidos se cargaron ordenados por fecha: entradas vecinas en el índice están en el mismo bloque. IX_PED_CLIENTE CF = **999 041** ≈ 1 000 000 filas (MALO) porque `id_cliente` se repartió al azar: casi cada entrada salta de bloque. El cálculo a mano da los mismos valores. **REBUILD no lo arregla**: el CF es propiedad del orden de la tabla, no del índice; habría que reordenar la tabla (CTAS/MOVE ordenado, clustering por atributo), y eso empeoraría el CF de fecha.

**8. Punto de equilibrio medido:** con CF malo el índice gana hasta 0,1 % (975 frente a 5232) y a 0,5 % ya está igualado (4875 frente a 5232); a partir del **≈0,5 %** pierde (1 % = 9920). Fórmula: k/r < 1/bfr = 1/188 = **0,53 %** en lecturas lógicas, y 0,11 % en disco (c_sec/c_aleat = 1/5); el optimizador cambia a recorrido completo ya en 0,2 % porque razona en coste de E/S física. Con CF bueno el índice compensa hasta un porcentaje muy alto: 3938 lecturas al 50 % frente a 5232 → equilibrio entre el 50 % y el 100 % (≈66 %); al 100 % pierde (7875).

**9. Q4b `'Gonz%'`:** es sargable (rango sobre el principio de la cadena) y usa IX_CLI_APELLIDOS, pero devuelve 2056 filas (2,1 %) y lee **2024** bloques frente a **1523** del recorrido completo de Q4a. El 2,1 % supera el equilibrio de CLIENTE (1/66 ≈ 1,5 %) y el índice tiene CF malo (clientes al azar): casi un bloque de tabla por fila. Sargable no significa "más barato".

### Coste de escritura y mantenimiento (G, H)

**10. Coste por INSERT** (`06-indices.script.log`, por fila): hoy, 4 índices = **10,1** bloques; propuesta del compañero, 9 índices = **20,2** (el doble de redo: 2553 frente a 1305 bytes); V005, 5 índices = **12,1**. Rechacé:
- **IX_PED_CANAL**: 3 valores (33 % por valor, no viable) y no lo usó la carga (`USA = NO`).
- **IX_PED_ESTADO**: 4 valores (25 %); lo sustituye el parcial IX_PED_PENDIENTES (54 hojas frente a 2933 de `(estado, fecha)`).
- **IX_PED_FEC_CLI**: no usado y hacía redundante a IX_PED_FECHA.
- **IX_PED_CLI_FEC** pasó a su versión cubriente IX_PED_CLI_FEC_CUB (Q7: 3 lecturas), que empieza por `id_cliente` y protege la clave ajena; por eso cae **IX_PED_CLIENTE** (prefijo redundante).
- **IX_PED_IMPORTE**: no usado; invisible, Q2 sigue en 331 lecturas.
- Se acepta **IX_PED_CP** (Q3: 5232 → 106) y **UX_CLI_DNI** (regla de negocio).
Precio que vigilo: el UPDATE de estado pasa de 2 a 8,1 bloques/fila por mantener la columna virtual del índice parcial.

**11. Gráficos de la Parte H** (`07a-*`, `07b-*`):
- **50/50 (IX_AZAR):** 595 divisiones, 0 de ellas 90/10, 336 entradas/hoja, 75,4 % de ocupación, histograma repartido entre 40 % y 99 % y mapa irregular `[==-====-==#===------…]`.
- **90/10 (IX_CRECIENTE):** 398 divisiones, **todas** 90/10, 501/hoja, 99,9 %, mapa todo `#`.
- **Patrón cola (IX_COLA):** 425 hojas, **224 vacías**, 70 245 entradas borradas (41 %), mapa vacío a la izquierda y lleno a la derecha `[                                =####…]`; "siguiente mensaje" lee **226** bloques frente a 2 del índice sano.
- (REVERSE: 511 divisiones 50/50, 77,9 %, y un rango pasa de 4 a 878 lecturas.)

**12. Remedio en producción en horario de servicio:** **COALESCE** — en línea, sin bloquear, barato, y resuelve el síntoma (`07c-remedios`: hojas 425 → 201, borradas 70 245 → 0, lecturas 226 → **2**). SHRINK SPACE si además quiero devolver espacio (4 → 1,69 MB), también en línea. REBUILD ONLINE solo con causa medida (espacio doble y mucho redo). La cura de fondo es de diseño: particionar por fecha y vaciar particiones.

### SCN, control files, redo y FRA (I a L)

**13. Al abrir** (`08-scn-checkpoint.script.log`), Oracle compara el **SCN de checkpoint del control file** (`v$datafile.checkpoint_change#`) con el de la **cabecera de cada datafile** (`v$datafile_header`): 5 246 822 = 5 246 822 → "sincronizado"; tras el `CHECKPOINT`, 5 252 475 en ambos. Si una cabecera es más antigua, ese archivo necesita recuperación de medios; si el control file no tiene SCN de parada (cierre no limpio), hace recuperación de instancia. PDB$SEED se queda en 2 098 101 porque está en solo lectura.

**14. Multiplexación en el mismo volumen** (`09-multiplexar-controlfile.script.log`: control01, 02 y 03, de 18 792 448 bytes cada uno): protege del borrado o corrupción de **una** copia (justo el simulacro B), pero no de perder el disco o volumen, porque las tres están en `/opt/oracle/oradata/FREE`. En producción: copias en discos o grupos ASM distintos (+DATA, +FRA), más `CONFIGURE CONTROLFILE AUTOBACKUP ON` en RMAN (en el simulacro D se generó el autobackup `o1_mf_s_…bkp`) y la copia a traza (`controlfile_lab5.trc`).

**15. Estados del redo** (`10-redo.script.log`): **CURRENT** es el grupo en el que escribe LGWR (grupo 3, secuencia 15); **ACTIVE**, uno ya lleno que todavía hace falta para la recuperación de instancia (sus cambios no han llegado a los datafiles) o que aún no se ha archivado (grupos 1 y 2, secuencias 13 y 14); **INACTIVE**, uno que ya no hace falta y se puede reutilizar. Los tres borrados se rechazan:
- `ORA-01623`: no se puede borrar el grupo CURRENT.
- `ORA-01609`: no se puede borrar un miembro del grupo CURRENT.
- `ORA-00350`: el grupo 1 aún necesita archivarse (y no pueden quedar menos de dos grupos).

**16. FRA llena** (`11-fra-llena.script.log`):
1. Se encoge la FRA a 2 MB.
2. ARCn no puede archivar: `ORA-19809` y `ORA-16038` (log 2, secuencia 17).
3. El alert log avisa: `ORA-19815: db_recovery_file_dest_size of 2097152 bytes is 100.00% used`.
4. Los grupos llenos quedan sin archivar (17 y 18 con `ARC = NO`).
5. Cuando LGWR da la vuelta y necesita reutilizar un grupo sin archivar, no puede: las sesiones esperan en *log file switch (archiving needed)* y la base deja de aceptar cambios.

Solución: devolver los 4 GB a la FRA; ARCn reintenta solo (17 y 18 pasan a `YES`, FRA usada 7 MB). En producción, además, `DELETE ARCHIVELOG` con RMAN después de hacer copia.

### Undo, WAL y simulacros (M a P)

**17. "Lectores no bloquean a escritores"** (`12-lectura-consistente.script.log`):
1. Mientras A tiene la fila 101 cambiada sin COMMIT, B lee `ACTIVO` (el valor confirmado, reconstruido con el undo) sin esperar.
2. La transacción de A ya consume 1 bloque y 1 registro de undo (SID 223).
3. A tiene un TM en modo 3 y un TX en modo 6.
4. Solo cuando B quiere **escribir** (`FOR UPDATE WAIT 3`) se bloquea: `ORA-00054`.

Leer nunca pide bloqueos de fila: ni el lector espera al escritor ni al revés; solo dos escritores sobre la misma fila se esperan.

**18. Undo por operación** (`12-undo-y-redo.script.log`, 10 000 filas):
- INSERT: 142 bloques de undo (1136 KB), porque el undo solo guarda "borra este ROWID".
- UPDATE: 158 bloques (1264 KB), el valor anterior de las columnas cambiadas.
- DELETE: **427** bloques (3416 KB), porque guarda la fila entera y sus entradas de índice para poder reinsertarlas.

El ROLLBACK también genera redo (355, 2470 y 4700 KB respectivamente) porque deshacer es aplicar cambios a bloques de datos, y todo cambio en un bloque se protege con redo. El propio undo también genera redo (2042, 1490 y 3262 KB del redo describe el undo).

**19. Durabilidad** (`13-lgwr-dbwn.script.log`):
- **Tras el COMMIT:** LGWR escribió 6288 KB de redo (4 escrituras, 1 commit), DBWn **0** bloques y quedan **231** bloques sucios en la caché. La garantía está en el **redo log online** (write-ahead logging).
- **Tras el CHECKPOINT:** DBWn escribió **532** bloques y quedan 0 sucios. Los datos ya están en los **datafiles**, y ese redo deja de hacer falta para la recuperación de instancia (sigue en el archivado para la de medios).

**20. Simulacro A** (`14a-caida-instancia.script.log`): antes del `SHUTDOWN ABORT`, la fila 102 → EGRESADO (confirmada) y la 103 → INACTIVO (sin confirmar). Al arrancar, el alert log muestra la recuperación:
- *Beginning crash recovery of 1 threads*
- *Recovery starting at checkpoint rba (logseq 19 block 62059), scn 5256618*
- *read 13 KB redo, 6 data blocks need recovery*
- *Completed redo application*
- *Completed crash recovery*

**Roll forward**: se aplica todo el redo desde el último checkpoint, incluidos el cambio de la 103 y su undo. **Roll back**: con ese undo se deshace la transacción no confirmada. Resultado: 102 = EGRESADO (sobrevive), 103 = ACTIVO (deshecha). RPO 0.

**21. RTO y RPO de los simulacros C y D:**
- **C** (`14c`): RTO **65 s**; RPO = todo lo posterior a la copia (aquí 1 s; en la vida real, horas o días). Hay que restaurar la copia en frío del volumen completo, sin aplicar redo: la base entera se cae y vuelve al instante de la copia.
- **D** (`14d`): RTO **9 s** (10 s desde el fallo); RPO **0** (la fila 104, confirmada después de la copia, sobrevivió). Solo se restaura un datafile y RMAN aplica el redo archivado y el online: ARCHIVELOG + RMAN.

**22. Errores ORA- del bloque 5 del runbook** (`15-healthcheck.spool.log`):

| Error | Origen | Clasificación |
|---|---|---|
| ORA-01113 file 22 needs media recovery (×2) | Simulacro D, durante la reparación | Efecto del laboratorio |
| ORA-63999 data file suffered media failure | Simulacro D: Oracle cerró FREEPDB1 al perder el archivo | Efecto del laboratorio |
| ORA-01110 data file 16 academia01.dbf | Simulacro D (archivo borrado a propósito) | Efecto del laboratorio |
| ORA-00800 Set Priority Failed [LGWR]/[VKTM] (×4) | El contenedor Docker en WSL no permite prioridad de tiempo real | Ruido conocido (inofensivo) |
| ORA-00202 control03.ctl / ORA-205 durante MOUNT | Simulacro B (copia borrada a propósito) | Efecto del laboratorio |

Ningún incidente real: todo coincide con la hora de un simulacro o es ruido del entorno. El resto del runbook está sano: FRA al 2 %, 3 control files, 0 grupos con un solo miembro, copia RMAN COMPLETED, ORA-01555 = 0.

---

## 2. Simulacro de examen 1Z0-182

| # | Resp. | Justificación (y dónde lo comprobé) |
|---|---|---|
| S1 | **B** | CF ≈ filas → casi un bloque distinto por fila (Parte E: IX_PED_CLIENTE, 999 041) |
| S2 | **A, C** | Índice funcional (Parte D, Q1: 4 lecturas) o reescribir con LOWER(:e) (Parte F, regla 1) |
| S3 | **B** | Plan: `filter(TO_NUMBER("CODIGO_POSTAL")=30001)` (Parte F, regla 3) |
| S4 | **B** | Bitmap en almacén con baja cardinalidad (Parte D, Q14: 4073 → 528) |
| S5 | **B** | INDEX SKIP SCAN de IX_CLI_PAIS_CIUDAD solo con ciudad (Parte D, Q6) |
| S6 | **B** | INVISIBLE, vuelta atrás inmediata (Parte G, pregunta 5) |
| S7 | **A, C** | COALESCE y SHRINK SPACE en línea (Parte H: 226 → 2 lecturas) |
| S8 | **B** | REVERSE reparte la hoja caliente pero un rango lee 878 (Parte H) |
| S9 | **C** | UPDATE de columna no indexada: 2 bloques con 4 o 9 índices (Parte G) |
| S10 | **B** | La altura depende del fan-out, es decir, del tamaño de la clave (Reto C: email altura 3) |
| S11 | **A, C** | IOT: filas en el índice de la PK, sin salto a tabla (Parte D, Q15: 3 lecturas) |
| S12 | **B** | SCN de checkpoint del control file frente al de la cabecera (Parte I) |
| S13 | **C** | CKPT actualiza control file y cabeceras (Parte I) |
| S14 | **B, E** | En NOMOUNT solo hay vistas de la instancia, sin control file (Simulacro B, estado STARTED) |
| S15 | **B** | MOUNT → ARCHIVELOG → OPEN (Parte L, 11-activar-archivelog) |
| S16 | **B** | CLEAR LOGFILE recrea un grupo INACTIVE ya archivado (Parte K) |
| S17 | **A, C** | Lectura consistente y flashback query (Parte M, pasos 1 y 6) |
| S18 | **B** | El undo vive en bloques que hay que rehacer antes de deshacer (Parte M.2) |
| S19 | **A** | COMMIT = redo en el log online; DBWn 0 bloques (Parte N) |
| S20 | **A** | Checkpoints incrementales más agresivos, menos MTTR (Parte I, v$instance_recovery) |
| S21 | **B** | ARCn no puede archivar: FRA llena (Parte L.2) |
| S22 | **B** | Primero aislar: datafile OFFLINE (Simulacro D, runbook) |
| S23 | **B** | SYSTEM no puede ir offline con la base abierta: MOUNT, RESTORE, RECOVER, OPEN |
| S24 | **B** | Sin ARCHIVELOG solo queda la copia en frío; se pierde lo posterior (Simulacro C) |
| S25 | **B, D** | Más UNDO_RETENTION y tamaño; RETENTION GUARANTEE si es crítica (Parte M, v$undostat) |
| S26 | **A** | V$RECOVERY_AREA_USAGE (Parte L, uso por FILE_TYPE) |

(Pregunta tipo examen C2: 2 000 000 de hojas con fo 500 → 1 + ⌈log₅₀₀ 2·10⁶⌉ = 1 + 3 = 4 → **C**.)

---

## 3. Tabla RTO/RPO de los simulacros (game day)

| Simulacro | Qué se rompió | Recuperación | RTO medido | RPO |
|---|---|---|---|---|
| A · Caída de instancia | `SHUTDOWN ABORT` | Automática al arrancar (roll forward + roll back) | ≈ 9 s (20:38:45 → 20:38:54) | 0 (la fila 102 sobrevive) |
| B · Pérdida de control file | Se borra `control03.ctl` | Copiar una copia sana y MOUNT/OPEN desde NOMOUNT | ≈ 8 s (20:38:54 → 20:39:02) | 0 |
| C · DROP TABLE … PURGE | `ACA_MATRICULAS` sin papelera | Restaurar la copia completa del volumen | **65 s** | Todo lo posterior a la copia (aquí 1 s) |
| D · Pérdida de datafile | Se borra `academia01.dbf` | RMAN RESTORE + RECOVER del archivo | **9 s** (10 s desde el fallo) | **0** (la fila 104 sobrevive) |

Además, en el simulacro C el DROP sin PURGE se resolvió en segundos con `FLASHBACK TABLE … TO BEFORE DROP` (60 000 matrículas).

---

## 4. Retrospectiva sin culpables (blameless)

**Qué salió bien.**
- Las 17 partes se ejecutaron con un commit por parte y su evidencia.
- La verificación final dio **TODO OK**.
- Los cuatro simulacros recuperaron los datos: RPO 0 en A, B y D.
- El escaneo de secretos dio 0 coincidencias.

**Qué falló y por qué.**
1. El primer intento se paró en la Parte A porque `scripts/lab4` no estaba en `main` y el contenedor estaba parado (todas las comprobaciones salían vacías).
2. Al arrancarlo aparecieron 7 fallos reales: no se habían ejecutado las Partes J a O del Lab 4. Se completaron en un commit propio (`chore(lab4): complete Lab 4 parts J-O…`) antes de hacer la copia `lab4-final`.
3. La base ya estaba en ARCHIVELOG al empezar el Lab 5, así que `11-activar-archivelog.sh` no necesitó reiniciar.

**Lo que aprendí.** La diferencia entre el simulacro C (65 s, se pierde lo posterior a la copia) y el D (9 s, RPO 0) es exactamente lo que aportan ARCHIVELOG y RMAN. Un control de "¿está el contenedor arriba?" antes de cualquier verificación ahorra diagnósticos falsos.

**Acciones de mejora.**
1. Añadir al runbook diario un paso 0 con `docker ps` y `esperar-healthy.sh`.
2. En un entorno real, llevar la tercera copia del control file y los miembros `b` del redo a otro disco.
3. Programar `BACKUP DATABASE PLUS ARCHIVELOG` diario con borrado de archivados ya copiados, para que la FRA no se llene.
