# Fuente única del plano

`vdl-btz-gui/steps.yml` es la **única fuente** de los 15 pasos del plano `blueprints/vdl-btz-gui/`. De ahí salen tres vistas que antes había que mantener idénticas a mano:

| Vista | Qué se genera |
|---|---|
| `blueprints/vdl-btz-gui/tasks.json` | toda la lista de tareas (se conserva el `status` de cada una) |
| `blueprints/vdl-btz-gui/blueprint.md` | el mapa y los pasos de §9, entre los marcadores `GENERATED:steps` |
| `blueprints/vdl-btz-gui/epics/*.md` | los bloques de tarea, entre los marcadores `GENERATED:tasks` |

```bash
ruby blueprints/source/sync.rb vdl-btz-gui           # regenera las vistas desde steps.yml
ruby blueprints/source/sync.rb vdl-btz-gui --check   # no escribe: sale con 1 si algo se desfasó
```

## Cómo cambiar un paso
1. Edita `steps.yml` (criterios, comandos `verify`, archivos, texto de **Do**…).
2. Ejecuta `ruby blueprints/source/sync.rb vdl-btz-gui`.
3. Haz commit de la fuente y de las vistas juntas.

El resto del plano (secciones 1–8 y 10–20 de `blueprint.md`, la cabecera de cada épica, `workspace/`) sigue editándose a mano.

## Qué comprueba el generador
Antes de escribir nada valida las reglas de la plantilla: de 1 a 6 criterios y hasta 5 archivos por tarea, títulos de 60 caracteres como máximo, ids y etiquetas únicos, dependencias existentes y anteriores, y `new_files` dentro de `files`. `test/blueprint_sync_test.rb` ejecuta `--check` dentro de `rake test`, así que una edición a mano de una zona generada hace fallar las pruebas.
