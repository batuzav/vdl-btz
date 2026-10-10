# vdl-btz

Herramienta de línea de comandos (CLI) escrita en Ruby para descargar videos y audio de **TikTok, YouTube, Instagram y Facebook**, y de muchos otros sitios, con un solo comando.

```bash
vdl-btz "https://www.tiktok.com/@usuario/video/1234567890"
```

- **Fácil de usar:** pegas la URL y listo. Detecta la plataforma automáticamente.
- **Multiplataforma:** macOS, Linux y Windows.
- **Sin instalaciones complicadas:** la primera vez que lo usas descarga solo lo que necesita (`yt-dlp` y `ffmpeg`) en `~/.vdl-btz/bin`, sin pedir permisos de administrador.
- **Sin dependencias de gemas:** usa solo la librería estándar de Ruby.
- Barra de progreso, descargas múltiples, solo audio en MP3, elección de calidad y mensajes de error con sugerencias en español.

---

## Índice

1. [Requisitos](#requisitos)
2. [Instalación](#instalación)
3. [Uso rápido](#uso-rápido)
4. [Comandos y opciones](#comandos-y-opciones)
5. [Configuración](#configuración)
6. [Contenido privado (cookies)](#contenido-privado-cookies)
7. [Solución de problemas](#solución-de-problemas)
8. [Cómo funciona](#cómo-funciona)
9. [Desarrollo](#desarrollo)
10. [Aviso legal](#aviso-legal)

---

## Requisitos

Solo necesitas **Ruby 2.7 o superior**. Para comprobar si lo tienes:

```bash
ruby -v
```

Si no lo tienes:

| Sistema | Cómo instalar Ruby |
|---|---|
| **macOS** | Viene preinstalado en versiones antiguas. Recomendado: `brew install ruby` |
| **Linux (Debian/Ubuntu)** | `sudo apt install ruby-full` |
| **Linux (Fedora)** | `sudo dnf install ruby` |
| **Windows** | Descarga el instalador de [rubyinstaller.org](https://rubyinstaller.org/) (versión *with Devkit*) |

> No necesitas instalar `yt-dlp` ni `ffmpeg`: **vdl-btz los instala automáticamente la primera vez que lo usas.**

---

## Instalación

### Opción 1: instalar como comando global (recomendado)

```bash
git clone https://github.com/TU_USUARIO/download_videos_free.git
cd download_videos_free
gem build vdl-btz.gemspec
gem install ./vdl-btz-0.1.0.gem
```

Con eso, el comando `vdl-btz` queda disponible desde cualquier carpeta:

```bash
vdl-btz help
```

> Si tienes `rake`, puedes reemplazar los dos últimos pasos por `rake install`.

### Opción 2: usarlo sin instalar

Desde la carpeta del proyecto:

```bash
ruby bin/vdl-btz "https://youtu.be/abc123"
```

### Primer uso

La primera vez que descargas algo verás algo así:

```
› Primer uso: instalando el motor de descarga (yt-dlp)...
✔ yt-dlp 2026.08.19 instalado
› Primer uso: instalando ffmpeg (para mejor calidad y MP3)...
✔ ffmpeg instalado

› YouTube  https://youtu.be/abc123
  ↓ Título del video
  [=================>            ]  58.3%  2.10MiB/s  ETA 00:04
✔ Guardado en: /Users/tu/Downloads/vdl-btz/youtube/Título del video [abc123].mp4
```

También puedes preparar todo de antemano con `vdl-btz setup`.

---

## Uso rápido

> ⚠️ **Siempre pon la URL entre comillas.** En macOS (zsh) y Linux, los caracteres `?` y `&` de las URLs causan errores como `zsh: no matches found` si no van entre comillas.

```bash
# Descargar un video en la mejor calidad
vdl-btz "https://www.youtube.com/watch?v=abc123"

# TikTok, Instagram o Facebook: igual de simple
vdl-btz "https://www.tiktok.com/@usuario/video/1234567890"
vdl-btz "https://www.instagram.com/reel/ABC123/"
vdl-btz "https://www.facebook.com/watch?v=1234567890"

# Varios videos a la vez
vdl-btz "URL1" "URL2" "URL3"

# Solo el audio en MP3
vdl-btz "https://youtu.be/abc123" --audio

# Elegir la calidad
vdl-btz "https://youtu.be/abc123" -q 720

# Guardar en otra carpeta
vdl-btz "https://youtu.be/abc123" -o ~/Videos

# Descargar una lista de URLs desde un archivo
vdl-btz -f lista.txt

# Ver información del video sin descargarlo
vdl-btz info "https://youtu.be/abc123"
```

### Dónde se guardan los archivos

Por defecto se guardan en `~/Downloads/vdl-btz/`, organizados por plataforma:

```
~/Downloads/vdl-btz/
├── youtube/
├── tiktok/
├── instagram/
├── facebook/
└── otros/
```

### Archivo de lista (`-f`)

Pon una URL por línea. Las líneas vacías y las que empiezan con `#` se ignoran:

```text
# Videos para el viernes
https://www.youtube.com/watch?v=abc123
https://www.tiktok.com/@usuario/video/1234567890
https://www.instagram.com/reel/ABC123/
```

---

## Comandos y opciones

### Comandos

| Comando | Descripción |
|---|---|
| `vdl-btz URL [URL...]` | Descarga uno o varios videos |
| `vdl-btz info URL` | Muestra título, autor, duración y calidades disponibles |
| `vdl-btz setup` | Instala `yt-dlp` y `ffmpeg` (con `--force` los reinstala) |
| `vdl-btz update` | Actualiza `yt-dlp` a la última versión |
| `vdl-btz doctor` | Revisa que todo esté bien instalado |
| `vdl-btz config` | Muestra o cambia la configuración |
| `vdl-btz help` | Muestra la ayuda |
| `vdl-btz version` | Muestra la versión |

### Opciones de descarga

| Opción | Corta | Descripción | Ejemplo |
|---|---|---|---|
| `--audio` | `-a` | Solo audio en MP3 | `-a` |
| `--quality` | `-q` | `best`, `2160` (o `4k`), `1440`, `1080`, `720`, `480`, `360` | `-q 1080` |
| `--output` | `-o` | Carpeta de destino | `-o ~/Videos` |
| `--file` | `-f` | Archivo con URLs (una por línea) | `-f lista.txt` |
| `--cookies` | `-c` | Usa la sesión de tu navegador | `-c chrome` |
| `--playlist` | `-p` | Descarga la playlist completa | `-p` |

Las opciones se pueden combinar:

```bash
vdl-btz -f lista.txt -q 720 -o ~/Videos/clases
```

> **Sobre la calidad:** `-q 720` descarga la mejor versión disponible **hasta** 720p. Si el video no llega a esa calidad, se descarga la más alta que tenga. Siempre se prefiere MP4 para máxima compatibilidad.

> **Sobre playlists:** si pegas un enlace de YouTube que pertenece a una playlist (`...&list=...`), por defecto se descarga **solo ese video**. Usa `-p` para bajar la lista completa.

---

## Configuración

Puedes guardar tus preferencias para no escribirlas cada vez:

```bash
vdl-btz config                          # ver la configuración actual
vdl-btz config set output ~/Videos      # carpeta por defecto
vdl-btz config set quality 1080         # calidad por defecto
vdl-btz config set cookies chrome       # usar siempre la sesión de Chrome
vdl-btz config set cookies none         # dejar de usar cookies
vdl-btz config reset                    # volver a los valores por defecto
```

La configuración se guarda en `~/.vdl-btz/config.yml`. Las opciones que escribes en el comando siempre tienen prioridad sobre la configuración guardada.

---

## Contenido privado (cookies)

Algunos videos piden iniciar sesión: publicaciones de cuentas privadas de Instagram, videos de grupos de Facebook o videos de YouTube con restricción de edad. Para descargarlos:

1. Abre la red social en tu navegador e **inicia sesión**.
2. Usa la opción `--cookies` con el nombre de tu navegador:

```bash
vdl-btz "https://www.instagram.com/p/ABC123/" --cookies chrome
```

Navegadores soportados: `chrome`, `firefox`, `edge`, `safari`, `brave`, `opera`, `chromium`, `vivaldi`.

> Las cookies se leen localmente desde tu navegador y solo se envían a la plataforma de la que descargas. vdl-btz no las guarda ni las comparte.
>
> En Windows, si Chrome o Edge están abiertos, a veces no se pueden leer las cookies. Ciérralos por completo o usa `firefox`.

---

## Solución de problemas

Primero ejecuta:

```bash
vdl-btz doctor
```

| Problema | Solución |
|---|---|
| `zsh: no matches found` | Pon la URL entre comillas: `vdl-btz "URL"` |
| `command not found: vdl-btz` | Reinstala la gema (ver [Instalación](#instalación)) o usa `ruby bin/vdl-btz` |
| Un sitio que antes funcionaba ya no descarga | Las plataformas cambian a menudo. Ejecuta `vdl-btz update` |
| "Este contenido requiere iniciar sesión" | Usa `--cookies chrome` (ver [Contenido privado](#contenido-privado-cookies)) |
| YouTube pide "confirmar que no eres un bot" | Usa `--cookies chrome` |
| El audio no sale en MP3 / la calidad es baja | Falta `ffmpeg`. Ejecuta `vdl-btz setup` |
| Algo quedó mal instalado | `vdl-btz setup --force` |

### ¿Dónde instala las cosas?

Todo queda en una sola carpeta, fácil de borrar:

```
~/.vdl-btz/
├── bin/          # yt-dlp, ffmpeg, ffprobe
└── config.yml    # tu configuración
```

Para desinstalar por completo:

```bash
gem uninstall vdl-btz
rm -rf ~/.vdl-btz          # en Windows: rmdir /s %USERPROFILE%\.vdl-btz
```

Si prefieres otra ubicación, define la variable de entorno `VDL_BTZ_HOME`.

---

## Cómo funciona

Las plataformas de video cambian sus páginas y protecciones con mucha frecuencia, así que mantener un descargador propio para cada una es poco práctico. Por eso vdl-btz se apoya en **[yt-dlp](https://github.com/yt-dlp/yt-dlp)**, un proyecto open source muy mantenido que soporta más de 1000 sitios, y en **[ffmpeg](https://ffmpeg.org/)** para unir audio y video y convertir a MP3.

vdl-btz se encarga de:

- Instalar automáticamente el binario correcto para tu sistema y arquitectura.
- Ofrecer comandos simples en español en lugar de las decenas de opciones de yt-dlp.
- Elegir formatos compatibles (MP4/MP3) y organizar los archivos por plataforma.
- Mostrar el progreso y traducir los errores a sugerencias útiles.

Si `ffmpeg` no se puede instalar, vdl-btz sigue funcionando: descarga el mejor archivo que ya trae audio y video juntos y guarda el audio en su formato original.

| Sistema | yt-dlp | ffmpeg |
|---|---|---|
| macOS | binario universal oficial | evermeet.cx (Intel) / Homebrew (Apple Silicon, si está instalado) |
| Linux x64 / ARM64 | binario oficial | builds estáticos de yt-dlp/FFmpeg-Builds |
| Windows x64 | `yt-dlp.exe` oficial | builds estáticos de yt-dlp/FFmpeg-Builds |

---

## Desarrollo

```bash
git clone https://github.com/TU_USUARIO/download_videos_free.git
cd download_videos_free
rake test                   # ejecutar los tests
ruby bin/vdl-btz help       # probar sin instalar
```

Estructura del proyecto:

```
download_videos_free/
├── bin/vdl-btz                # punto de entrada del comando
├── lib/vdl_btz.rb
├── lib/vdl_btz/
│   ├── cli.rb                 # comandos y opciones
│   ├── downloader.rb          # ejecuta yt-dlp y procesa el progreso
│   ├── installer.rb           # instala yt-dlp / ffmpeg según el sistema
│   ├── platform.rb            # detecta TikTok / YouTube / Instagram / Facebook
│   ├── config.rb              # configuración en ~/.vdl-btz/config.yml
│   ├── hints.rb               # traduce errores a sugerencias
│   ├── ui.rb                  # colores, mensajes y barra de progreso
│   ├── os.rb                  # detección del sistema operativo
│   ├── paths.rb               # rutas de la herramienta
│   └── version.rb
├── test/                      # tests con Minitest
├── vdl-btz.gemspec
└── Rakefile
```

Las contribuciones son bienvenidas: abre un *issue* o un *pull request*.

---

## Aviso legal

Esta herramienta es para **uso personal**. Descarga solo contenido del que seas autor, que tenga licencia libre o que tengas permiso para guardar. Respeta los derechos de autor y los términos de servicio de cada plataforma. Los autores no se hacen responsables del mal uso de este software.

## Licencia

[MIT](LICENSE)
