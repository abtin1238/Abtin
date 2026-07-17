# Vosk Persian STT model

Place the offline Persian model here, for example:

```
assets/vosk/model-fa/
  am/
  conf/
  graph/
  ivector/
```

Then set native `isModelReady` to `true` in:
- `android/.../MainActivity.kt`
- `ios/Runner/AppDelegate.swift`

Dart API: `VoskSttService` + `VoiceCommand.parseCommand`.
Without the model, voice **commands still work** via typed input / injectText.
