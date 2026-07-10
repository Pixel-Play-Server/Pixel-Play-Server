# AutoReel

Generador automático de reels para iOS. Escribes un tema y la app hace todo:

1. **NVIDIA NIM** genera guion, escenas y keywords de búsqueda
2. **Pexels / Unsplash** descargan fotos de internet automáticamente
3. **ElevenLabs** sintetiza la narración
4. **FFmpeg en el iPhone** monta el video (Ken Burns, subtítulos, export 9:16)

## Requisitos

- macOS con Xcode 16+ **o** compilar en CI con GitHub Actions (ver abajo)
- iPhone físico recomendado para ejecutar (FFmpeg es pesado en simulador)
- API keys:
  - [NVIDIA Build](https://build.nvidia.com) (NIM) — la app elige el mejor modelo automáticamente (Llama 3.3, GLM-5.2, Nemotron…) con streaming para evitar timeouts
  - [ElevenLabs](https://elevenlabs.io)
  - [Pexels](https://www.pexels.com/api/)
  - [Unsplash](https://unsplash.com/developers) (opcional, fallback)

## Instalación

```bash
# 1. Instalar XcodeGen (si no lo tienes)
brew install xcodegen

# 2. Generar el proyecto Xcode
cd AutoReel
xcodegen generate

# 3. Abrir en Xcode
open AutoReel.xcodeproj
```

## Descargar en iPhone (sin PC)

Tras cada build exitoso en `main` o ramas `cursor/**`, se publica un **GitHub Release** con el IPA:

**https://github.com/Pixel-Play-Server/Pixel-Play-Server/releases**

1. Abre el enlace en Safari (o app **GitHub**)
2. Entra al release marcado como **Latest**
3. Descarga `AutoReel-v1.0-bX.ipa`
4. **Archivos** → mantén pulsado → **Compartir** → **SideStore**

> Los artefactos de Actions a veces no se descargan en iPhone; los **Releases** sí.

## Compilar sin Mac reciente (GitHub Actions)

Si tu Mac no soporta Xcode reciente, el workflow [`.github/workflows/ios-build.yml`](../.github/workflows/ios-build.yml) compila en los runners de GitHub (`macos-15` + Xcode estable más reciente).

**Se dispara automáticamente** al hacer push o PR que toque `AutoReel/`.

**Ejecución manual:** en GitHub → Actions → *iOS Build (AutoReel)* → *Run workflow*.

Tras un build exitoso en push, el IPA aparece en **Releases** (arriba). También hay artefacto `AutoReel-ipa` en Actions como respaldo.

> El CI embebe y firma todos los frameworks de FFmpegKit dentro del `.app`. Sin esto, la app crashea al abrir (`dyld: Library not loaded`).

### Firma con tu certificado (.p12) — usar Secrets, NO el repo

**No subas el `.p12` al repositorio.** Contiene tu clave privada; cualquiera con acceso al repo podría firmar apps en tu nombre.

Configura estos **GitHub Secrets** (Settings → Secrets and variables → Actions):

| Secret | Valor |
|--------|--------|
| `IOS_CERTIFICATE_P12_BASE64` | Tu `.p12` en base64 (ver abajo) |
| `IOS_CERTIFICATE_PASSWORD` | Contraseña del export del .p12 |
| `IOS_PROVISIONING_PROFILE_BASE64` | Perfil `.mobileprovision` en base64 |

También necesitas un **perfil de aprovisionamiento** para el bundle ID `com.autoreel.app` con tu iPhone registrado. Créalo en [developer.apple.com](https://developer.apple.com) → Certificates, Identifiers & Profiles.

**Convertir archivos a base64** (en Linux/Mac):

```bash
base64 -w 0 tu_certificado.p12
base64 -w 0 tu_perfil.mobileprovision
```

En macOS sin `-w 0`:

```bash
base64 -i tu_certificado.p12 | tr -d '\n'
```

Si los tres secrets están configurados, el CI firma el IPA automáticamente. Si no, genera un IPA ad-hoc para SideStore como antes.

### Si crashea al iniciar

1. Asegúrate de usar un IPA **reciente** (build ≥ 2 en Ajustes → General → Almacenamiento si ves la versión).
2. Reinstala desde SideStore tras descargar el artefacto nuevo de GitHub Actions.
3. Si sigue fallando, conecta el iPhone a un Mac y revisa **Consola.app** → crash log de `AutoReel`.

## Configuración

Al abrir la app por primera vez, introduce tus API keys en **Ajustes**. Se guardan en el **Keychain** del dispositivo.

## Logs de depuración (sin Mac)

La app guarda logs en la carpeta **Documents**, visible desde la app **Archivos** de iOS:

```
Archivos → En mi iPhone → AutoReel → AutoReel/logs/app.log
```

También puedes verlos dentro de la app: icono **📄** en la barra superior → *Ver y compartir logs*.

Útil si compilas solo con GitHub Actions y no tienes Xcode/Mac para ver crashes.

## Flujo automático

```
Tema del usuario
      ↓
NVIDIA NIM → JSON con escenas + image_query en inglés
      ↓
Pexels API → descarga fotos (IA elige la mejor)
      ↓
ElevenLabs → narration.mp3
      ↓
FFmpegKit (on-device)
  ├── imagen → clip con zoompan (Ken Burns)
  ├── concat de clips
  ├── subtítulos ASS quemados
  └── mezcla con voz → final_reel.mp4
      ↓
Preview + compartir + copy/hashtags
```

## Arquitectura

```
AutoReel/
├── Services/
│   ├── AI/           NIMClient, AIOrchestrator
│   ├── Media/        Pexels, Unsplash, ImageFetcher
│   ├── Voice/        ElevenLabsClient
│   └── Video/        FFmpegService, VideoPipeline, SubtitleGenerator
├── ViewModels/
└── Views/            Prompt, Progress, Preview, Settings
```

## FFmpeg en iPhone

Usa [ffmpeg-kit-spm](https://github.com/codewithtamim/ffmpeg-kit-spm) vía Swift Package Manager (~60–80 MB en el IPA). El tamaño no importa según el diseño: todo el render ocurre en el dispositivo.

Comandos que ejecuta internamente:

- `zoompan` — efecto Ken Burns en cada imagen
- `concat` — unir clips por escena
- `subtitles` — quemar subtítulos estilo viral
- `libx264` + `aac` — export H.264 listo para Reels

## Notas legales

Las imágenes se obtienen vía APIs oficiales (Pexels/Unsplash), no scraping arbitrario. Respeta las licencias de cada plataforma al publicar.

## Próximos pasos

- [ ] Música de fondo automática (Pixabay Music API)
- [ ] Generación de imágenes con NVIDIA Diffusion si no hay stock
- [ ] Transiciones `xfade` entre clips
- [ ] Guardar en galería con `PHPhotoLibrary`
- [ ] Templates visuales predefinidos

## Licencia

Código del proyecto: según el repositorio principal. FFmpeg se distribuye bajo LGPL/GPL según la build de FFmpegKit.
