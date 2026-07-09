# AutoReel

Generador automático de reels para iOS. Escribes un tema y la app hace todo:

1. **NVIDIA NIM** genera guion, escenas y keywords de búsqueda
2. **Pexels / Unsplash** descargan fotos de internet automáticamente
3. **ElevenLabs** sintetiza la narración
4. **FFmpeg en el iPhone** monta el video (Ken Burns, subtítulos, export 9:16)

## Requisitos

- macOS con Xcode 16+
- iPhone físico recomendado (FFmpeg es pesado para el simulador)
- API keys:
  - [NVIDIA Build](https://build.nvidia.com) (NIM)
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

## Configuración

Al abrir la app por primera vez, introduce tus API keys en **Ajustes**. Se guardan en el **Keychain** del dispositivo.

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

Usa [kingslay/FFmpegKit](https://github.com/kingslay/FFmpegKit) vía Swift Package Manager (~60–80 MB en el IPA). El tamaño no importa según el diseño: todo el render ocurre en el dispositivo.

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
