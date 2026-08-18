# Campfire Flutter — plano de execução

Cliente Flutter com **a mesma cara e as mesmas funções** do app Tauri atual, falando com o mesmo servidor FastAPI + LiveKit que já está em produção. O servidor não muda: os contratos (`/api/*`, `/gateway`, tokens do LiveKit) são os mesmos, então o app novo é um segundo consumidor de uma API que já existe e já está testada.

Este documento é o plano de obra. Cada tarefa tem id, dono de fila (*lane*), dependência explícita e critério de pronto, para várias frentes andarem ao mesmo tempo sem se atropelar.

---

## 1. Escopo

**Dentro:** tudo que o cliente atual faz — conectar a servidor self-hosted, login/registro por convite, canais de texto, anexos (foto/vídeo/arquivo) com player próprio, menções, respostas, edição/exclusão, gateway em tempo real, presença, canais de voz, câmera, compartilhamento de tela, DMs com chamada 1:1 (toque, aceitar/recusar), notificações e sons.

**Fora da v1:** paridade de atalhos de teclado do desktop, *picker* nativo de tela do Windows (aquilo é código Rust específico do Tauri), Flutter Web, e chamada com o app **fechado** — esta última depende de push (FCM/APNs), que o servidor não tem hoje. Ver §9.

**Alvos:** Android e iOS primeiro (é o que o Tauri não entrega hoje), com desktop (Windows/macOS/Linux) saindo de graça do mesmo código, exceto o compartilhamento de tela.

---

## 2. Decisões de stack

| Camada | Escolha | Por quê |
| :--- | :--- | :--- |
| Estado | **Riverpod** (~~com `riverpod_generator`~~, ver nota) | Os stores zustand atuais (`auth`, `channels`, `messages`, `dms`, `voice`, `presence`, `users`, `server`, `settings`) mapeiam 1:1 para providers. Sem `BuildContext` para ler estado, que é o que permite portar `gateway.ts` quase literal. |
| Modelos | **freezed** + **json_serializable** | `lib/types.ts` vira código gerado: união selada para os 12 eventos do gateway, `copyWith` para as atualizações otimistas do chat. |
| HTTP | **dio** | Precisa de interceptor com *refresh* de token em fila única e de progresso de upload — os dois já existem em `api/client.ts` e o dio cobre ambos. |
| WebSocket | **web_socket_channel** | Porte direto de `ws/gateway.ts` (reconexão com backoff, READY, heartbeat). |
| Voz/vídeo | **livekit_client** (SDK oficial Flutter) | Mesmo SFU, mesmo token emitido por `/api/voice/{id}/token`. Suporta Android/iOS/desktop. |
| Navegação | **go_router** | O mobile precisa de botão voltar e deep link de convite; o `App.tsx` hoje é um `switch` de estado, que vira `redirect` do go_router. |
| Segredos | **flutter_secure_storage** | Equivalente ao `secureStore.ts` (Keychain/Keystore em vez do plugin store do Tauri). |
| Notificação | **flutter_local_notifications** | Paridade com `lib/notifications.ts`. |
| Chamada recebida | **flutter_callkit_incoming** | Tela de chamada nativa (CallKit no iOS, ConnectionService no Android) para o `DM_CALL`. |
| Áudio de UI | **audioplayers** | Toca os mesmos assets de `client/public/sounds`. |
| Lint | **very_good_analysis** | Regra estrita desde o commit 1; barato agora, caro depois. |

> **Sem `riverpod_generator`.** A versão publicada exige um `analyzer` incompatível
> com o Dart 3.12 deste SDK (`riverpod_lint`/`custom_lint` idem). Os providers são
> escritos à mão, o que no Riverpod 3 custa pouco. Revisitar quando o pacote
> alcançar o SDK — a migração é mecânica.

---

## 3. Paridade de funcionalidades

| Função | Hoje (React) | No Flutter | Risco |
| :--- | :--- | :--- | :--- |
| Conectar a servidor | `ServerConnectScreen` | idem + `/health` antes de salvar | baixo |
| Login / registro por convite | `LoginScreen`, `RegisterWithInviteScreen` | idem | baixo |
| Sessão persistida | `state/auth.ts` + `secureStore` | Riverpod + secure storage | baixo |
| Lista de canais, CRUD admin | `ChannelSidebar`, `ChannelMenu` | lista + menu por *long press* | baixo |
| Mensagens + paginação | `ChatPane`, `state/messages.ts` | `ListView` reverso + `before` | médio |
| Menções @/# | `lib/mentions.ts` (puro) | porte direto + testes | baixo |
| Respostas, editar, apagar | `MessageItem` | idem | baixo |
| Anexos + progresso | `MessageComposer`, `AttachmentList` | `file_picker`/`image_picker` + `onSendProgress` | médio |
| Player de áudio/vídeo | `MediaPlayer.tsx` (510 linhas) | `video_player` + controles próprios | médio |
| Lightbox de imagem | `ImageLightbox` | `InteractiveViewer` + `Hero` | baixo |
| Gateway em tempo real | `ws/gateway.ts` (252 linhas) | porte direto | médio |
| Presença | `state/presence.ts` | idem | baixo |
| Voz (entrar, mute, fala) | `livekit/voice.ts` | `livekit_client` | médio |
| Câmera | `setCameraEnabled` | idem | baixo |
| Compartilhar tela | Rust + WGC (Windows) | MediaProjection / ReplayKit | **alto** |
| DMs 1:1 + não lidas | `DirectMessageSidebar` | idem | baixo |
| Chamada em DM (toque) | `CallCenter`, `DirectCallPanel` | + CallKit | **alto** |
| Notificações | `lib/notifications.ts` | `flutter_local_notifications` | baixo |
| Tema noite/ember | `index.css` (oklch) | tokens convertidos | médio |

---

## 4. Arquitetura de pastas

Espelha o cliente atual de propósito — quem conhece um acha as coisas no outro.

```
app/
  lib/
    main.dart
    app.dart                 # MaterialApp + go_router (= App.tsx)
    api/
      client.dart            # dio, baseUrl dinâmico, refresh em fila
      endpoints.dart         # os ~20 endpoints tipados
    models/                  # freezed: user, channel, message, attachment, dm, invite, events
    state/                   # providers: auth, channels, messages, dms, presence, users, voice, server, settings
    ws/gateway.dart
    livekit/voice.dart
    screens/                 # server_connect, login, register, shell, text_channel, voice_channel, dm
    widgets/                 # channel_sidebar, message_item, composer, user_bar, media_player, ...
    theme/                   # tokens.dart (gerado), theme.dart, night_sky.dart
    core/                    # mentions.dart, files.dart, sounds.dart, notifications.dart, secure_store.dart
                             #   (era `lib/`; um `lib/lib/` dá imports `package:campfire/lib/...`)
  test/                      # unit + widget
  integration_test/
```

---

## 5. Design system

O visual não é "tema escuro genérico": é um gradiente índigo com brilho de brasa animado, painéis translúcidos por cima e sotaque âmbar. Reproduzir isso é trabalho de verdade, não `ThemeData.dark()`.

- **Cores**: `index.css` define tudo em `oklch`, que o Flutter não entende. Tarefa A2 converte os tokens do bloco `.dark` para `Color` em tempo de build e gera `theme/tokens.dart` — assim o dia em que o CSS mudar, roda-se o script de novo em vez de acertar hex na mão.
- **Superfícies de vidro**: `--glass`, `--glass-border` são branco com alfa baixo sobre o gradiente; no Flutter é `Container` com `color: white.withValues(alpha: .07)` + `BackdropFilter` onde o CSS usa `backdrop-blur`.
- **Brasa animada**: as `@property --ember-glow-*` animam um gradiente radial. No Flutter, `AnimatedBuilder` + `RadialGradient` num `DecoratedBox` de fundo do shell.
- **Tipografia**: Fraunces (variável) para títulos, Geist para o resto. Empacotar os `.ttf` em `assets/fonts` em vez de baixar em runtime — o app precisa abrir offline e a fonte é parte da identidade.
- **Adaptação mobile**: esta é a maior divergência de layout. O desktop tem 4 colunas (rail, canais, chat, membros). No celular: rail + canais viram *drawer* à esquerda, membros vira *bottom sheet*, e o chat ocupa a tela toda. Tablet/desktop mantêm as colunas. Um único `AdaptiveShell` decide por *breakpoint* (tarefa I2).

---

## 6. Contratos que não mudam

Tudo isso já existe e está no ar — o app novo consome, não redefine.

- **REST**: `/api/auth/{login,register,refresh,logout}`, `/api/channels` (+ `PATCH`/`DELETE`), `/api/channels/{id}/messages`, `/api/messages/{id}`, `/api/uploads`, `/api/dms` (+ `call`, `call/accept`, `read`), `/api/users`, `/api/server`, `/api/invites`, `/api/voice/{id}/token`.
- **Gateway** (`/gateway`, 12 ops): `READY`, `MESSAGE_CREATE|UPDATE|DELETE`, `TYPING_START`, `PRESENCE_UPDATE`, `VOICE_STATE_UPDATE`, `CHANNEL_CREATE|UPDATE|DELETE`, `DM_UPDATE`, `DM_CALL`.
- **Autenticação**: JWT access (15 min) + refresh (30 dias); o refresh precisa ser de fila única, senão N requisições paralelas disparam N refreshes e invalidam a sessão.

> O `READY` traz usuário, servidor, canais, DMs, presença e estado de voz numa frame só. O app **não** deve buscar essas listas por REST no boot — o cliente atual não busca, e duplicar isso gera divergência de estado.

**Uma divergência já encontrada:** `_build_ready_payload` (`gateway/router.py`) monta
os dicionários de `user` e `channels` à mão e **não inclui `created_at`**, enquanto
`UserRead`/`ChannelRead` do REST incluem. O `types.ts` declara o campo como
obrigatório nos dois casos e o cliente React nunca percebeu porque não valida. No
Flutter, `User.createdAt` e `Channel.createdAt` são nulos, com teste fixando as duas
formas. Nada precisa mudar no servidor; se um dia mudar, é acrescentar o campo nos
dois dicionários e apertar o modelo.

---

## 7. Micro-tasks

Tamanhos: **S** ≤ 2h · **M** ~meio dia · **L** 1–2 dias.
"Depende" vazio = pode começar agora.

Estado: **✅** pronto e verificado no CI · **🟡** parcial (o que falta está na
linha) · sem marca = não começou.

### Lane A — Fundação e design system

| id | tarefa | dep | tam | pronto quando |
| :-- | :-- | :-- | :-- | :-- |
| ✅ A1 | `flutter create`, estrutura de pastas, `very_good_analysis`, `melos`/scripts | — | S | `flutter analyze` limpo no CI |
| ✅ A2 | Script oklch→sRGB gerando `theme/tokens.dart` a partir de `index.css` | A1 | M | tokens do bloco `.dark` batem com o app atual em captura lado a lado |
| ✅ A3 | `ThemeData`/`ColorScheme` + tipografia (Fraunces/Geist empacotadas) | A2 | M | tela em branco com fundo e fonte corretos |
| 🟡 A4 | Widgets base: botão, input, diálogo, menu (popup + long-press), avatar com status, tooltip | A3 | L | galeria de widgets renderiza os 6 — *botão, input e diálogo saem do `ThemeData`; faltam avatar com status, menu por long-press e a galeria* |
| ✅ A5 | Shell de fundo: gradiente night-sky + brasa animada | A3 | M | animação em 60fps, sem jank no perfil |
| ✅ A6 | Ícones (`lucide_icons`) e mapa dos usados hoje | A1 | S | ícone equivalente para cada um do cliente |
| 🟡 A7 | Sons de UI + assets de `client/public/sounds` | A1 | S | join/leave/ringtone tocam — *assets empacotados; falta o `audioplayers` e o ringtone, que hoje é sintetizado no `ringtone.ts` e não existe como arquivo* |

### Lane B — Contratos e rede

| id | tarefa | dep | tam | pronto quando |
| :-- | :-- | :-- | :-- | :-- |
| ✅ B1 | Modelos freezed espelhando `lib/types.ts` | A1 | M | `flutter test` de serialização passa |
| ✅ B2 | Eventos do gateway como união selada (12 ops) | B1 | S | `switch` exaustivo compila |
| ✅ B3 | `ApiClient` dio: baseUrl do `serverUrl`, injeção de Bearer | B1 | M | GET `/api/server` autenticado responde |
| ✅ B4 | Refresh em fila única + logout no 401 | B3 | M | teste com 5 requisições paralelas dispara 1 refresh |
| 🟡 B5 | Os ~20 endpoints tipados | B3 | M | cada um coberto por teste contra fixture — *os ~20 escritos; só auth/refresh/server cobertos por teste* |
| 🟡 B6 | Upload com progresso + `resolveAssetUrl` | B3 | M | barra de progresso reflete bytes enviados — *`upload` com `onSendProgress` e `resolveAssetUrl` prontos; falta a UI e o teste* |
| ✅ B7 | Secure storage: `serverUrl`, `refreshToken`, `user` | A1 | S | sobrevive a reinício do app |
| B8 | Fixtures capturadas do servidor real + testes de contrato | B1 | M | quebra se o servidor mudar formato |

### Lane C — Estado

| id | tarefa | dep | tam | pronto quando |
| :-- | :-- | :-- | :-- | :-- |
| ✅ C1 | `authProvider`: login, register, restore, logout | B4,B7 | M | sessão restaura sem tela de login |
| 🟡 C2 | `settingsProvider`: serverUrl + normalização | B7 | S | aceita `dominio.com` e vira `https://dominio.com` — *`normalizeServerUrl` portado e testado; falta o provider* |
| ✅ C3 | `GatewayClient`: conexão, backoff, READY, dispatch | B2,C1 | L | reconecta sozinho ao derrubar o Wi-Fi |
| ✅ C4 | `channelsProvider` (+ eventos CHANNEL_*) | C3 | S | canal criado em outro cliente aparece |
| C5 | `messagesProvider`: paginação, envio otimista, MESSAGE_* | C3 | L | rolar para cima carrega página anterior |
| C6 | `dmsProvider`: lista, não lidas, DM_UPDATE | C3 | M | contador zera ao abrir |
| 🟡 C7 | `usersProvider` + `presenceProvider` | C3 | S | bolinha muda ao outro sair — *`presenceProvider` pronto; falta `usersProvider`* |
| C8 | `voiceProvider`: participantes, mute, quem fala | C3 | M | estado bate com VOICE_STATE_UPDATE |
| ✅ C9 | `serverProvider` (nome, ícone, limite de upload) | C3 | S | nome do servidor no topo |

### Lane D — Onboarding

| id | tarefa | dep | tam | pronto quando |
| :-- | :-- | :-- | :-- | :-- |
| ✅ D1 | `ServerConnectScreen` com checagem de `/health` | A4,C2 | M | erro claro em endereço inválido |
| ✅ D2 | `LoginScreen` (+ trocar de servidor) | A4,C1 | M | login no servidor de produção funciona |
| ✅ D3 | `RegisterWithInviteScreen` | A4,C1 | M | registro por código cria conta |
| ✅ D4 | Roteamento/splash: restore → connect → auth → shell | C1,C2 | M | reabrir o app cai direto no chat |

### Lane E — Chat

| id | tarefa | dep | tam | pronto quando |
| :-- | :-- | :-- | :-- | :-- |
| E1 | Porte de `mentions.ts` (puro) + testes | A1 | M | mesmos casos do original passam |
| E2 | Porte de `files.ts` (tipo, tamanho, download) + testes | A1 | S | idem |
| E3 | Lista de mensagens: `ListView` reverso, agrupamento, separador de data | C5,A4 | L | 500 mensagens rolam sem jank |
| E4 | `MessageItem`: autor, hora, editada, ações | E3 | M | editar/apagar refletem no outro cliente |
| E5 | Render de menções com destaque | E1,E4 | S | `@fulano` e `#canal` estilizados |
| E6 | Composer: texto, enviar, `TYPING_START` | C5 | M | indicador aparece no outro cliente |
| E7 | Composer: anexos (arquivo, foto, câmera) + progresso | E6,B6 | L | 3 arquivos sobem com progresso |
| E8 | Autocomplete de `@`/`#` | E1,E6 | M | navegação por teclado e toque |
| E9 | Responder a mensagem | E4,E6 | M | prévia da citada acima do composer |
| E10 | `AttachmentList` + cartão de arquivo + salvar | E2,E4 | M | arquivo salva com nome original |
| E11 | Lightbox de imagem | E10 | S | pinça para zoom, arrastar para fechar |
| E12 | `TypingIndicator` | E6 | S | some após timeout |

### Lane F — Voz

| id | tarefa | dep | tam | pronto quando |
| :-- | :-- | :-- | :-- | :-- |
| F1 | `livekit_client`: entrar/sair, permissões de microfone | C8,B5 | L | dois aparelhos se ouvem |
| F2 | Mute, deafen, indicador de quem fala | F1 | M | anel do avatar acende ao falar |
| F3 | Câmera (ligar/desligar, trocar frontal/traseira) | F1 | M | vídeo aparece nos dois lados |
| F4 | Compartilhar tela: Android (MediaProjection + serviço em primeiro plano) | F1 | L | tela compartilhada é vista pelo outro |
| F5 | Compartilhar tela: iOS (extensão ReplayKit) | F4 | L | idem — **isolado, cortável da v1** |
| F6 | `VoiceChannelView`: grade de participantes/tiles | F2,A4 | L | 4 participantes cabem sem sobrepor |
| F7 | Barra de controles adaptada ao mobile | F2 | M | alcançável com o polegar |
| F8 | Sons de entrada/saída | F1,A7 | S | toca só para os outros, não para si |

### Lane G — DMs e chamadas

| id | tarefa | dep | tam | pronto quando |
| :-- | :-- | :-- | :-- | :-- |
| G1 | Lista de DMs + não lidas | C6,A4 | M | ordena por última mensagem |
| G2 | Tela de DM reaproveitando o chat | E3,G1 | M | anexos e respostas funcionam |
| G3 | Iniciar DM com alguém da lista | C7,G1 | S | get-or-create não duplica conversa |
| G4 | Sinalização `DM_CALL` (ringing/accept/decline/cancel) | C3,G1 | L | recusar encerra dos dois lados |
| G5 | Tela de chamada + toque | G4,A7 | M | toca até atender ou expirar |
| G6 | CallKit/ConnectionService (app em segundo plano) | G5 | L | chamada aparece na tela de bloqueio |
| G7 | Painel da chamada em andamento (áudio/vídeo/tela) | G4,F3 | M | trocar de mídia sem cair |

### Lane H — Mídia

| id | tarefa | dep | tam | pronto quando |
| :-- | :-- | :-- | :-- | :-- |
| H1 | `VideoPlayer` com controles próprios (porte do `MediaPlayer.tsx`) | A4 | L | play/scrub/volume/velocidade iguais |
| H2 | `AudioPlayer` com os mesmos controles, sem imagem | H1 | S | clipe de voz na lista |
| H3 | Tela cheia + PiP | H1 | M | rotação e PiP no Android |

### Lane I — Plataforma

| id | tarefa | dep | tam | pronto quando |
| :-- | :-- | :-- | :-- | :-- |
| I1 | Notificações locais + permissão | C3 | M | menção notifica com app em segundo plano |
| I2 | `AdaptiveShell` (drawer no celular, colunas no tablet/desktop) | A4 | L | mesmo código nos dois formatos |
| I3 | Ciclo de vida: reconectar ao voltar, áudio em segundo plano | C3,F1 | M | chamada sobrevive a bloquear a tela |
| I4 | Deep link de convite (`campfire://invite/CODE`) | D3 | M | link abre já no registro |
| 🟡 I5 | Ícone, splash, nome, permissões declaradas | A1 | S | instala com identidade certa — *nome e `INTERNET` prontos; faltam ícone, splash e as permissões de mídia (lane F)* |

### Lane J — Qualidade e entrega

| id | tarefa | dep | tam | pronto quando |
| :-- | :-- | :-- | :-- | :-- |
| ✅ J1 | CI: `analyze` + `test` em todo push | A1 | S | workflow verde |
| J2 | CI: build de APK/AAB assinado, anexado ao release | J1 | M | instalável baixado do GitHub |
| J3 | CI: build iOS sem assinatura (compila) | J1 | M | quebra cedo se o iOS quebrar |
| J4 | Testes de integração contra o compose de dev | B8,D2 | L | roda no CI com o servidor em serviço |
| J5 | Distribuição interna (pre-release rolante, igual ao Windows) | J2 | S | link único sempre com o build novo |

---

## 8. Marcos

| Marco | Entrega | Tarefas |
| :-- | :-- | :-- |
| ✅ **M0** | App abre com a identidade visual certa | A1–A3, A6, B1, B7, J1 |
| 🟡 **M1** | Entra no servidor de produção e vê a lista de canais | B3–B5, C1–C4, C9, D1–D4 |
| **M2** | Conversa: lê, escreve, menciona, responde, edita | C5, E1, E3–E6, E8, E9, E12 |
| **M3** | Manda e abre mídia | B6, E2, E7, E10, E11, H1, H2 |
| **M4** | Fala: canal de voz com mute, fala e câmera | C8, F1–F3, F6–F8 |
| **M5** | DM com chamada, notificação, celular de verdade | C6, C7, G1–G7, I1–I3 |
| **M6** | Entrega contínua | I5, J2–J5, e então F4/F5 se ficarem de pé |

**M0 fechou** — mais A5 (brasa animada) e B2 (união dos eventos), que vieram junto
porque A5 é o que faz "identidade visual certa" significar alguma coisa e B2 é uma
tarefa S em cima de B1. O `flutter analyze --fatal-infos` e os 43 testes passam,
e o APK debug compila e instala.

**M1 está de pé menos a prova final.** O caminho completo existe e é testado —
connect com `/health`, login, registro por convite, sessão restaurada, socket
aberto, READY preenchendo canais/servidor/presença, lista de canais na tela. O que
falta é rodar isso contra o servidor de produção com uma conta de verdade; até lá
M1 fica 🟡. B5 e B6 têm código completo mas cobertura parcial, e A4 ainda não
existe como conjunto de widgets — as telas de auth se viram com o `ThemeData`.

**Frentes que rodam em paralelo desde o dia 1**, sem esperar ninguém: ~~A1 (fundação)~~, E1 e E2 (portes puros com teste, não dependem de UI), H1 (player, só precisa do tema), B8 (fixtures do servidor, que já está no ar), ~~J1 (CI)~~.

Com três frentes simultâneas, M0–M2 é a metade do caminho e é onde o app deixa de ser esqueleto.

---

## 9. Riscos

| Risco | Impacto | Como atacar |
| :-- | :-- | :-- |
| **Compartilhar tela no iOS** exige extensão ReplayKit, processo separado, com limite de memória | alto | F5 isolada e cortável; a v1 pode sair só com Android |
| **Chamada com app fechado** precisa de push (FCM/APNs); o servidor não tem | alto | v1 toca só com socket vivo (app aberto ou em segundo plano recente). Push é trabalho **de servidor**, planejado à parte |
| **Refresh de token em paralelo** invalidando sessão | médio | B4 com teste explícito de concorrência antes de qualquer tela |
| **Fidelidade visual** (translucidez, brasa, oklch) | médio | A2 gera tokens do CSS; revisão por captura lado a lado, não por memória |
| **Rolagem de listas longas** com anexos e vídeo | médio | E3 com `ListView.builder` reverso e teste de 500 mensagens desde cedo |
| **Bugs que só existem em release** — o template do Flutter declara `INTERNET` apenas nos manifests de debug/profile, então o APK release não tinha rede nenhuma e nada disso aparece em `flutter run` | médio | Já aconteceu. `manifest_test.dart` trava este caso; a lição geral é que o que se testa no aparelho tem que ser o artefato que se entrega, que é o que J2 automatiza |
| **Divergência de estado** entre READY e REST | médio | Regra do §6: no boot, só READY |
| **Eco/roteamento de áudio no mobile** (fone, viva-voz) | médio | F1 já com `audio_session` configurado para chamada |

---

## 10. O servidor precisa mudar?

Para a v1, **não**. Três ressalvas:

1. **Push** (chamada com app fechado) exigiria endpoint de registro de token e envio via FCM/APNs.
2. **Flutter Web**, se um dia entrar, exige acrescentar a origem em `cors_origins`.
3. **Avatares**: hoje o usuário não tem foto; o app mostra inicial. Se quiser foto, é upload + campo no modelo — mesma mudança nos dois clientes.

---

## 11. Como isso convive com o cliente atual

Os dois falam com o mesmo servidor e podem ficar no ar ao mesmo tempo, inclusive na mesma conta. O repositório ganha `app/` ao lado de `client/` e `server/`; a esteira de deploy do servidor não muda, e o Flutter entra com workflows próprios (J1–J3), do mesmo jeito que `check-client.yml` e `build-windows.yml` cuidam do Tauri hoje.
