# Lab 3 — Instalación del entorno Oracle · Respuestas

Evidencias en `docs/bitacora/evidencia/{script,spool,capturas}/` (se cita el sufijo del archivo).

## Docker

**1. ¿Qué diferencia hay entre una imagen y un contenedor? (G2 y G4)**
La imagen es una plantilla de solo lectura (`hello-world`, `alpine:3.20`); el contenedor es una ejecución concreta de esa imagen, con su propio estado y una capa escribible. En G2, a partir de la imagen `hello-world` Docker creó un contenedor al que llamó `loving_jackson`. En G4 creé otro contenedor, `prueba`, desde `alpine:3.20`. De una misma imagen se pueden crear muchos contenedores.

**2. En G5 `nota.txt` desapareció y en G6 no. ¿Por qué?**
En G5 escribí el archivo en `/tmp`, dentro de la capa escribible del contenedor `prueba`. Al hacer `docker rm prueba` esa capa se borró con él, y `prueba2` nació limpio desde la imagen (`can't open '/tmp/nota.txt'`). En G6 lo escribí en `/datos`, donde estaba montado el volumen `datos-prueba`. El volumen vive fuera del contenedor (`/var/lib/docker/volumes/datos-prueba/_data`), así que otro contenedor distinto lo pudo leer.

**3. `docker ps` frente a `docker ps -a`, y `Exited (0)`.**
`docker ps` solo lista los contenedores en marcha; `docker ps -a` lista todos, también los parados. En G2, `docker ps` salió vacío y `docker ps -a` mostró `loving_jackson` en `Exited (0)`: el contenedor terminó y su proceso acabó con código 0, es decir, sin error.

**4. En `-p 8181:8181`, ¿qué número es de mi equipo y cuál del contenedor? ¿Y `-p 80:8080` con nginx?**
El formato es `equipo:contenedor`: el primero es el puerto de mi equipo y el segundo el del contenedor. En G7 usé `-p 8080:80` y `docker port web` mostró `80/tcp -> 0.0.0.0:8080`. Con `-p 80:8080` mi equipo escucharía en el 80 y lo enviaría al 8080 del contenedor, pero nginx escucha en el 80 dentro del contenedor, así que la conexión no llegaría a ningún servicio y la página no cargaría.

**5. ¿Por qué el contenedor de Oracle se queda en marcha y hello-world termina solo?**
Un contenedor vive mientras vive su proceso principal. El de `hello-world` imprime el mensaje y termina. El de Oracle arranca la base de datos y el listener y se queda vigilándolos indefinidamente, por eso el contenedor sigue `Up (healthy)`.

**6. ¿Qué es el digest y por qué lo registramos si usamos `:latest`?**
Es la huella SHA-256 que identifica una versión exacta de la imagen, bit a bit. La mía es `sha256:f988b0c04c4c...` (`*_04-imagen`). `:latest` es una etiqueta móvil que Oracle va moviendo a versiones nuevas; el digest no cambia. Registrarlo permite saber exactamente qué versión instalé y reproducir el entorno.

**7. ¿Qué comando borraría realmente los datos de Oracle? ¿Por qué `docker rm oralab-26ai` no lo hace?**
`docker volume rm oralab-26ai-data` (después de borrar el contenedor que lo usa). `docker rm` solo borra el contenedor; los datafiles están en el volumen, que es independiente. Lo comprobé en el Lab 4: borré y recreé el contenedor y los 5 entornos seguían ahí.

## Git, organización y evidencia

**8. ¿Por qué se hace dentro del repositorio, con Issue, branch y PR?**
Porque preparar un entorno es un cambio de infraestructura como cualquier otro: el Issue explica qué y por qué, la rama aísla el trabajo, cada commit registra un paso con su evidencia, y el PR permite que otra persona lo revise antes de llegar a `main`. Queda trazable y reproducible: cualquiera puede ver qué se hizo, cuándo y repetirlo con los mismos scripts.

**9. `source 00-config.sh` frente a `bash 00-config.sh`.**
`bash` ejecuta el archivo en una shell nueva: las variables y la función `ts` se definen allí y desaparecen al terminar. `source` lo ejecuta en mi shell actual, así que `$CONT_NAME`, `$EVID` o `ts` quedan disponibles para los comandos siguientes. Lo vi en la práctica: al relanzar `script`, la shell nueva no tenía la función `ts` y el archivo salió como `_03-tutorial-docker.script.log`, sin fecha.

**10. Partes de `20260915T091230Z_02-docker.script.log`.**
`20260915` es la fecha (15 de septiembre de 2026); `T` separa fecha y hora; `091230` es la hora 09:12:30; `Z` indica que está en UTC. `02` es el número de paso, que ordena la evidencia; `docker` describe el contenido; `.script` indica que es una sesión de terminal capturada (frente a `.spool`, que es salida de SQL); y `.log` es la extensión. Con este formato los archivos se ordenan solos cronológicamente.

**11. ¿Para qué sirve `.gitattributes` y qué error evita?**
Fija el final de línea LF para `*.sh`, `*.sql` y `*.md`. Windows usa CRLF y Linux LF; un script con CRLF falla en Linux con errores como `$'\r': command not found`. Con `.gitattributes`, Git normaliza los finales de línea para todo el equipo y los diffs no se llenan de cambios invisibles.

**12. ¿Por qué Create a merge commit y no Squash and merge?**
Cada commit corresponde a una Parte (Docker, imagen, contenedor, arranque, migraciones, SQLcl, ORDS) y tiene valor propio: se ve cuándo y cómo se verificó cada herramienta. Squash los habría juntado en uno solo. Además, mi rama del Lab 4 salía de la del Lab 3: con merge commit, Git reconoció que esos commits ya estaban en `main` y el PR del Lab 4 mostró solo sus 10 commits.

## Seguridad

**13. Las cuatro capas de la estrategia de contraseñas y qué pasa si te saltas la primera.**
Capa 1: añadir `config/.env` a `.gitignore` antes de crear el archivo. Capa 2: una plantilla versionada sin secretos (`config/.env.example` con `change_me`). Capa 3: el archivo real local `config/.env`, comprobado con `git check-ignore -v`. Capa 4: cargar las contraseñas como variables con `set -a; source config/.env; set +a` y usar `"$ORACLE_PWD"` sin escribirla nunca. Si te saltas la primera, un `git add .` puede meter `config/.env` en un commit y la contraseña quedaría en el historial para siempre.

**14. ¿Por qué no escribir la contraseña en el `docker run`, aunque el script no se suba?**
Porque todo lo que se teclea queda en `~/.bash_history` en texto plano, y mientras se ejecuta se puede ver con `ps`. Con `"$ORACLE_PWD"` en el historial solo queda el nombre de la variable. Aun así, la variable acaba en la configuración del contenedor (`docker inspect`), por eso en el Lab 4 la versión 2 del script de creación ya no pasa la contraseña cuando reutiliza el volumen.

**15. Si la contraseña aparece en un commit publicado, ¿basta con borrarla?**
No: sigue en el historial y cualquiera puede recuperarla navegando hacia atrás. Hay que darla por comprometida y cambiarla (rotarla) de inmediato, avisar al docente o al responsable, y después limpiar el historial si la política lo exige. Me pasó algo parecido durante el laboratorio: compartí sin querer mi contraseña de SYS fuera del repositorio y la cambié en `config/.env` y en la base con `ALTER USER`. Al final comprobé con `git grep` y `git log -p` que ninguna contraseña real está en los archivos ni en los commits.

## Oracle y herramientas

**16. ¿Por qué no usamos SPOOL ni `@archivo.sql` con sqlplus dentro del contenedor?**
Porque ese sqlplus se ejecuta dentro del contenedor: no ve los archivos de mi repositorio y su SPOOL escribiría en el sistema de archivos del contenedor, no en mi carpeta de evidencias. En su lugar enviamos el `.sql` por la entrada estándar (`docker exec -i ... sqlplus ... < archivo.sql`) y guardamos la salida con `tee` en el repositorio. Con SQLcl, que está instalado en mi equipo, sí usamos SPOOL (evidencia 10).

**17. ¿Qué hace `WHENEVER SQLERROR EXIT SQL.SQLCODE` en V000 y V001?**
Si cualquier sentencia falla, sqlplus termina en ese momento devolviendo el código del error, y el script 08 lo detecta y se para. Sin esa línea, sqlplus seguiría ejecutando el resto después del error: la migración quedaría aplicada a medias y el script terminaría como si todo hubiera ido bien.

**18. ¿Qué es una migración y por qué V000 y V001 no se editan una vez aplicadas?**
Una migración es un script versionado y numerado que lleva la base de un estado al siguiente, y se aplica una sola vez y en orden. Si se edita una ya aplicada, el repositorio deja de describir lo que de verdad se ejecutó y un entorno nuevo acabaría distinto del existente. Los cambios se hacen con migraciones nuevas, como V002 y V003 en el Lab 4.

**19. ¿Por qué en SQL Developer se usa el servicio FREEPDB1 y no FREE ni un SID?**
La base es multitenant: `FREE` es el contenedor raíz (CDB$ROOT) y los datos de trabajo, con los 5 esquemas de negocio, están en la PDB `FREEPDB1`. A una PDB solo se llega por su nombre de servicio; el SID identifica la instancia y llevaría a la raíz. Lo comprobé en la primera conexión: `SHOW CON_NAME` devolvió `FREEPDB1`.

**20. ¿Qué aporta SQLcl frente a SQL*Plus, y por qué dominar ambas?**
SQLcl es la herramienta moderna: autocompletado, historial, formato automático (`SET SQLFORMAT ansiconsole`), conexiones guardadas (`CONNECT -save oralab26-system`) e integración con Liquibase, y se instala en mi equipo, así que su SPOOL escribe en el repositorio. SQL*Plus existe en cualquier servidor Oracle: cuando solo hay una terminal en el servidor es lo único disponible. Un DBA necesita las dos.

## Entorno de trabajo

**21. ¿Por qué pasar de Git Bash a Ubuntu en WSL 2? Dos problemas que desaparecen.**
Git Bash es una emulación de bash sobre Windows; Ubuntu en WSL 2 es Linux real, con su kernel, como los servidores donde se trabaja con Oracle. Problemas que desaparecen: los finales de línea CRLF que rompen los scripts; las rutas y permisos de Windows (no hay `chmod` real ni bits de ejecución); y la falta de herramientas de Linux (`apt`, `tmux`, `ss`, un Java y un SQLcl para Linux), que en este laboratorio instalé con `apt` sin problemas.

**22. ¿Por qué el repositorio en `~/oracle-database-lab` y no en `/mnt/c/...`? ¿Y por qué bash y no zsh?**
`/mnt/c` es el disco de Windows visto desde Linux a través de una capa de traducción: es mucho más lento para Git y no respeta bien permisos ni finales de línea. En `~` el repositorio está en el sistema de archivos nativo de Linux. Solo usé `/mnt/c` para copiar archivos puntuales, como los zip descargados o la captura. Los scripts se escriben para bash (`#!/usr/bin/env bash`) porque es la shell estándar de los servidores Linux; zsh tiene diferencias (por ejemplo, los arrays empiezan en 1 y la expansión de variables es distinta) que harían que algunos scripts se comportaran de otra forma.

## Incidencias resueltas durante el laboratorio

- Docker no respondía en Ubuntu: activé la integración de WSL en Docker Desktop (Settings → Resources → WSL integration).
- La imagen no crea el usuario `ALUMNO` (bloque 4 de la primera conexión: "no rows selected"); lo creé en la Parte M con `12-ords-habilitar-alumno.sql`.
- SQLcl rechazaba la contraseña de SYS porque tenía una ñ; la cambié por una solo con letras y números.
