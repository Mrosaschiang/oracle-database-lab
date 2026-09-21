# Laboratorio 1 — Respuestas de comprobación

Nombre: Mateo Eduardo Rosas Chiang

## 1. ¿Cuál es la diferencia entre Working Directory, Staging Area y Local Repository? Da un ejemplo de un archivo pasando por las tres.

El Working Directory es la carpeta normal donde uno edita los archivos, es lo que se ve en el explorador de Windows. La Staging Area es como una bandeja intermedia donde uno pone los archivos que quiere que entren en el próximo commit, ahí llegan con `git add`. Y el Local Repository es donde ya queda guardado para siempre el cambio, después de hacer `git commit`. Por ejemplo con el README.md: primero lo edité (Working Directory), luego hice `git add README.md` y pasó a la Staging Area, y con `git commit -m "..."` quedó guardado en el Local Repository.

## 2. Si modificas un archivo pero no haces git add, ¿aparece ese cambio en tu próximo commit? Explica por qué.

No aparece. Esto me pasó en el ejercicio de la Parte E cuando creé el archivo customer-schema.md y quise hacer commit directo sin el add, y Git me dijo "nothing added to commit but untracked files present". O sea que el commit solo agarra lo que está en la Staging Area, no lo que está solo en el Working Directory.

## 3. ¿Por qué git status no mostraba las carpetas vacías que creaste en la Parte C? ¿Qué truco usamos para solucionarlo?

Porque Git no versiona carpetas, solo versiona archivos. Una carpeta vacía no tiene nada adentro que Git pueda rastrear, entonces ni aparece. El truco fue meter un archivo `.gitkeep` dentro de cada carpeta vacía (scripts, runbooks, playbooks, database/schema, etc.), así al haber un archivo la carpeta ya se puede versionar.

## 4. Explica con tus palabras qué es HEAD.

HEAD es como un puntero que indica en qué commit o en qué branch estoy parado en este momento. Cuando hice `git switch` entre ramas, en el `git log --graph` se veía "(HEAD -> nombre-de-la-rama)" al lado del último commit de esa rama, mostrando dónde estoy ubicado ahora mismo dentro del historial.

## 5. ¿Qué diferencia hay entre crear una branch con git switch -c y crear una carpeta nueva con mkdir? ¿Cómo lo comprobamos en la Parte G?

`mkdir` crea una carpeta física nueva en el disco, se puede ver en el explorador de archivos. En cambio `git switch -c` crea una branch, que es solo un puntero dentro de la carpeta `.git`, no crea ninguna carpeta nueva visible. Lo comprobamos en la Parte G haciendo `ls -la` después de crear la branch feature/customer-search y viendo que salían exactamente las mismas carpetas de antes, no apareció ninguna carpeta llamada "feature".

## 6. Durante el conflicto de la Parte H, ¿qué representaba el contenido entre <<<<<<< HEAD y =======? ¿Y entre ======= y >>>>>>>?

Entre `<<<<<<< HEAD` y `=======` estaba la versión que yo ya tenía en mi rama actual (en mi caso era "Training Edition", de la rama fix/readme-title que ya había mergeado a master). Y entre `=======` y `>>>>>>> fix/readme-subtitle` estaba la versión que venía de la otra rama que estaba tratando de fusionar (la de "Academic Version").

## 7. ¿Por qué NO se debe hacer git commit --amend sobre un commit que ya se subió con git push?

Porque `--amend` no edita el commit, en realidad crea un commit nuevo con un hash distinto y el commit viejo deja de estar en la rama. Si ese commit ya se subió a GitHub y alguien más ya lo bajó a su compu, cuando yo hago amend y push otra vez, mi historial y el de esa persona ya no van a coincidir y se genera un lío para resolver. Por eso amend solo es seguro mientras el commit sea local nada más.

## 8. Si borras por accidente la carpeta .git de tu proyecto, ¿qué se pierde exactamente? ¿Se pierde también el código fuente que está en el disco?

Se pierde todo el historial de Git: los commits, las branches, los mensajes, todo lo que Git llevaba guardado internamente. Pero el código fuente que está físicamente en el disco (los archivos como README.md, las carpetas, etc.) no se borra, esos archivos siguen ahí normal, lo único es que ya no tienen ningún historial de versiones ni forma de volver atrás.

## 9. Explica con tus propias palabras la diferencia entre Git y GitHub, sin usar la palabra "nube".

Git es el programa que corre en mi propia computadora y hace todo el trabajo de versionado: guardar commits, crear branches, hacer merges, todo funciona sin internet. GitHub es una página web donde se guarda una copia de ese repositorio en un servidor externo, y sirve para que otras personas puedan ver mi código, colaborar, y además agrega cosas extra como pull requests y revisión de código que Git por sí solo no tiene.

## 10. ¿Por qué no se debe subir un archivo .env con contraseñas reales a un repositorio, aunque el repositorio sea privado?

Porque una vez que el archivo entra al historial de Git, queda ahí guardado para siempre aunque después se borre el archivo. Cualquiera con acceso al repositorio (o si en algún momento se hace público sin querer) puede ir al historial viejo y sacar esa contraseña. Además, si el repositorio se clona o se comparte, esas credenciales viajan con todo el proyecto.

## 11. Un compañero te dice: "hice push y ahora GitHub me rechaza el segundo push con 'non-fast-forward'". ¿Qué ha ocurrido probablemente y qué comando ejecutarías primero?

Seguramente el repositorio remoto en GitHub ya tiene commits que él no tiene todavía en su copia local, por ejemplo si alguien más hizo push antes, o si él mismo editó algo desde la web de GitHub (como me pasó a mí en la Parte I cuando edité el README desde el navegador). Lo primero que hay que hacer es un `git pull` para traer esos cambios y fusionarlos, y recién después intentar el `git push` de nuevo.

## 12. ¿Qué tipo de Conventional Commit (feat, fix, docs, test…) usarías para: añadir un índice de rendimiento a una tabla, corregir una restricción mal definida, y actualizar el README?

Para el índice de rendimiento usaría `perf`, porque es una mejora de rendimiento. Para corregir la restricción mal definida usaría `fix`, porque es arreglar un error. Y para actualizar el README usaría `docs`, porque es un cambio solo de documentación.
