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

Para conferir o layout ao lado do cliente React sem depender de um aparelho, há o
alvo web — **de desenvolvimento, não de entrega** (`PLANO_FLUTTER.md` §12):

```sh
flutter build web --release
(cd build/web && python3 -m http.server 1421)   # a origem liberada no CORS
```

> **Depois de adicionar um plugin, apague `.dart_tool/flutter_build` antes de
> compilar para a web.** O registrador de plugins do alvo web fica em cache ali;
> um build por cima do cache antigo compila e roda, mas o plugin novo não está
> registrado, e o erro que aparece é um `MissingPluginException` no meio de outra
> coisa — de vez em quando, e sem relação óbvia com a mudança. Já custou uma
> caçada duas vezes: uma na mídia (lane H), outra na voz (lane F).

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

## Ícone

A arte é a mesma que o cliente Tauri instala (`../client/src-tauri/app-icon.png`),
para os dois aparecerem iguais na gaveta de apps. Dois formatos saem dela, porque
o celular quer coisas opostas em cada plataforma:

```sh
python3 tool/generate_icon_sources.py   # assets/icon/{icon,icon_foreground}.png
dart run flutter_launcher_icons          # espalha nas densidades
```

O `icon.png` é o quadrado opaco do iOS e do Android antigo — a moldura arredondada
do desenho cai quase em cima da máscara do iOS, então ela fica, e os cantos
transparentes são preenchidos com uma cópia borrada da própria arte em vez de uma
cor chutada. O `icon_foreground.png` é só a cena, sem moldura: o ícone adaptativo
do Android recorta com a máscara que o launcher quiser, e uma moldura quadrada ali
viraria um quadrado preso dentro de um círculo. As duas saídas são commitadas; o
script só roda de novo se a arte mudar.

## Voz e chamadas

A sala é a mesma do cliente React — mesmo SFU, mesmo token de
`/api/voice/{id}/token`, mesma sala por canal. Duas coisas só existem deste lado
porque só existem no celular:

- **`CallService`** (`android/app/src/main/kotlin/.../CallService.kt`): um
  *foreground service* que não faz nada além de existir. Sem ele o Android 11
  tira o microfone assim que o app sai da tela, e o MediaProjection nem começa.
  O Dart o liga e desliga por `MethodChannel` (`lib/core/call_service.dart`).
- **Toques sintetizados** (`lib/core/ringtone.dart`): o navegador tem
  oscilador, o celular não, então um ciclo inteiro do padrão vira um WAV em
  memória e toca em *loop* — mesmas frequências e mesmo compasso de
  `lib/ringtone.ts`.

Para ver isso funcionando sem dois aparelhos, é o alvo web acima com duas abas
(dois logins) e o Chromium com `--use-fake-device-for-media-stream`.

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
