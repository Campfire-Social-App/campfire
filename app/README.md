# Campfire — cliente Flutter

Segundo cliente do mesmo servidor FastAPI + LiveKit, com a mesma cara e as
mesmas funções do app Tauri em `../client`. O servidor não muda: os contratos
(`/api/*`, `/gateway`, tokens do LiveKit) são os mesmos. Plano de obra completo
em [`../PLANO_FLUTTER.md`](../PLANO_FLUTTER.md).

## Rodar

```sh
flutter pub get
flutter run                  # Android/iOS
flutter test
flutter analyze
```

## Código gerado

Dois geradores, ambos com saída **commitada** e verificada no CI:

```sh
dart run build_runner build          # freezed + json_serializable (models/)
dart run tool/generate_tokens.dart   # theme/tokens.dart, a partir do CSS
```

`tool/generate_tokens.dart` lê `../client/src/index.css`, converte os tokens de
`oklch` para sRGB e escreve `lib/theme/tokens.dart`. É o que impede os dois
clientes de divergirem de cor: mudou o CSS, roda o script (`--check` falha se a
saída estiver velha). Ele também extrai as cores dos gradientes `.bg-night-sky`
e `.bg-starfield` e os dois extremos da animação `ember-breathe`.

## Estrutura

Espelha `../client/src` de propósito — quem conhece um acha as coisas no outro.

| Aqui | Lá |
| :--- | :--- |
| `lib/models/` | `src/lib/types.ts` |
| `lib/api/` | `src/api/` |
| `lib/state/` | `src/state/` (stores zustand → providers Riverpod) |
| `lib/ws/` | `src/ws/gateway.ts` |
| `lib/livekit/` | `src/livekit/voice.ts` |
| `lib/screens/`, `lib/widgets/` | `src/screens/`, `src/components/` |
| `lib/theme/` | `src/index.css` |
| `lib/core/` | `src/lib/` (utilitários puros: mentions, files, secure store) |

## Desvios do plano

- **`lib/core/` em vez de `lib/lib/`** (§4 do plano): um diretório `lib/lib` dá
  imports `package:campfire/lib/mentions.dart`. Mesmo conteúdo, nome melhor.
- **Sem `riverpod_generator`** (§2): a versão publicada exige um `analyzer`
  incompatível com o Dart 3.12 deste SDK. Os providers são escritos à mão, o que
  no Riverpod 3 custa pouco. Revisitar quando o pacote alcançar o SDK.
- **`User.createdAt` e `Channel.createdAt` são nulos**, ao contrário do que
  `types.ts` declara: o `READY` monta esses dicionários à mão em
  `gateway/router.py` e não inclui `created_at`, enquanto o REST inclui. O
  cliente React não tipa isso a sério e nunca percebeu; aqui está explícito.
