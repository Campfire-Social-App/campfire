# Transmissão de tela: estabilidade e validação

## Comparação com o Discord

O Campfire e o Discord usam WebRTC e encaminham a mídia por um servidor, em vez
de criar uma conexão direta entre quem transmite e cada espectador. A pilha não
é a mesma: o Campfire usa LiveKit como SFU e, na captura nativa, xcap/WGC → RGBA
→ JPEG → IPC do Tauri → canvas do WebView → codificador WebRTC. No navegador,
usa `getDisplayMedia()` → codificador WebRTC → LiveKit.

No aplicativo Tauri, o seletor e a captura são sempre nativos. A detecção usa a
API oficial `isTauri()`; `getDisplayMedia()` fica restrito à versão web e também
é bloqueado caso algum fluxo tente chamá-lo dentro do cliente.

O Discord documenta código próprio de captura e codificação integrado às APIs do
sistema e aos drivers de vídeo, com codificação por hardware quando disponível,
e usa WebRTC para transporte. Isso elimina a etapa JPEG/canvas que ainda existe
na captura nativa do Campfire. Portanto, compartilhamos o protocolo e a ideia de
SFU/adaptação de banda, mas não os mesmos frameworks nem o mesmo caminho de
captura. Referências oficiais: [visão geral do Go Live](https://discord.com/blog/how-it-all-goes-live-an-overview-of-discords-streaming-technology)
e [correções de FPS e encoder](https://discord.com/blog/from-blocky-to-brilliant-improving-video-quality-on-discord-go-live-on-amd-gpus).

## Correções no cliente

- O perfil padrão passa de 720p/2 Mbps para 1080p/30 FPS, com teto de 6 Mbps.
  Existe uma camada intermediária de 720p/2 Mbps entre a principal e 360p.
  Esses valores são limites, não garantia de resolução ou banda reservada.
- No web/desktop, 720p usa até 3 Mbps e 1080p até 6 Mbps em 30 FPS. Em 60 FPS,
  os tetos são 4,5 e 8 Mbps para manter margem ao controle de congestionamento.
  O seletor permite ajustar resolução/FPS também no navegador. Resolução nativa
  continua exclusiva da captura nativa do aplicativo.
- Adaptive stream no web/desktop considera a densidade real da tela, evitando
  subdimensionar o vídeo em monitores com escala 125%, 150% ou 200%.
- O JPEG intermediário da captura desktop usa qualidade 85 até 30 FPS e 76 em
  60 FPS, reduzindo o custo de IPC/decodificação quando a fluidez é prioritária.
  No máximo dois quadros podem ficar em trânsito; se a interface atrasar, a
  captura descarta quadros antigos em vez de acumular latência e congelar.
- Chamadas diretas esperam 30 segundos antes de encerrar por ausência do outro
  participante. O prazo é cancelado durante a reconexão e quando alguém retorna.
  Uma chamada encerrada normalmente pelo outro participante também pode permanecer
  aberta por até 30 segundos; desligar pelo próprio botão continua imediato.
- No cliente web/desktop, a interface indica reconexão e preserva a intenção de
  assistir à tela durante o reinício completo da sessão LiveKit.
- A captura nativa aceita um primeiro frame que tenha chegado antes da resposta
  IPC. Falhas de inicialização liberam a captura, e frames em decodificação não
  voltam a pintar depois do encerramento.
- O gravador nativo é liberado também em erros; seu encerramento inesperado é
  comunicado ao cliente. O intervalo entre frames passa a incluir o tempo de
  codificação, em vez de acrescentá-lo à espera.
- Até 30 FPS, a publicação prioriza resolução e legibilidade. Acima disso,
  prioriza a taxa de quadros e permite reduzir a resolução sob carga. Simulcast,
  adaptive stream e dynacast continuam ativos.
- O cliente Windows captura o áudio do sistema com WASAPI em 48 kHz estéreo e
  publica uma faixa LiveKit `ScreenShareAudio` independente. Em versões recentes
  do Windows, o processo do Campfire é excluído do loopback para não devolver as
  vozes da chamada; versões anteriores usam o loopback do dispositivo de saída.
- Durante uma transmissão, clicar novamente no botão de tela abre os controles
  com a fonte e o perfil atuais. É possível trocar janela/monitor, qualidade,
  FPS e áudio, aplicar as alterações ou encerrar a transmissão.

## Diagnóstico de FPS: onde cada etapa loga

O pipeline de captura nativa tem três estágios instrumentados com contadores
periódicos (uma linha a cada ~2s por estágio, não por frame), para isolar em
qual ponto o frame rate está caindo — por exemplo, ao comparar antes/depois de
abrir um jogo:

1. **Rust, captura/encode** (`src-tauri/src/capture.rs`) — via `log::info!`.
   Linhas `[capture:screen]`/`[capture:window]` trazem `produced_fps`
   (cadência da própria OS/xcap — WGC para tela, chamada de captura para
   janela, independente do que descartamos depois), `sent_fps`, `coalesced`
   (frames do recorder descartados por estarem obsoletos), `dropped_interval`
   (descartados pelo limite de FPS pedido) e `dropped_backpressure`
   (descartados porque o frontend ainda não confirmou o frame anterior), além
   de `encode_avg_ms`/`encode_max_ms` (JPEG + IPC) e
   `recv_gap_avg_ms`/`grab_avg_ms` (cadência bruta da fonte). Uma queda em
   `produced_fps` aponta para a captura do Windows (WGC/driver/GPU), não para
   este processo — é o sinal mais provável quando o problema só aparece com um
   jogo aberto, já que jogos em tela cheia exclusiva ou com alto uso de GPU
   competem diretamente com a captura por acesso à GPU.
2. **WebView, decodificação/pintura** (`src/lib/screenCapture.ts`). Linhas
   `[screen-share]` trazem `receivedFps` (quanto chega via IPC),
   `processedFps`, `staleDropped` (frames substituídos antes de serem
   decodificados) e `processAvgMs`/`processMaxMs` (decodificar + desenhar no
   canvas). Se `receivedFps` do Rust está saudável mas `processedFps` aqui cai,
   o problema é a thread principal do WebView — plausível se o jogo estiver
   roubando prioridade de CPU/GPU do processo do Campfire.
3. **Codificador WebRTC** (`src/livekit/voice.ts`). Linhas
   `[screen-share:webrtc]` vêm de `LocalVideoTrack.getSenderStats()` e
   trazem `fps`, `framesSent`, `targetBitrateKbps` e `qualityLimitation`.
   `qualityLimitation=cpu` indica que o próprio codificador de vídeo do
   navegador está disputando CPU/GPU — a etapa final do pipeline, depois do
   encode JPEG intermediário da captura nativa.

### Onde ver essas linhas

Um build empacotado não tem console visível e o DevTools do WebView2 vem
desabilitado por padrão em release — por isso os três estágios escrevem num
arquivo único, em vez de dependerem só da saída do console:

- As linhas de `capture.rs` (estágio 1) vão para `log` via `tauri-plugin-log`,
  que grava em `app_log_dir()` (no Windows, a pasta de logs do app) e também
  no stdout.
- As linhas de `screenCapture.ts` e `voice.ts` (estágios 2 e 3) são logadas no
  `console.info` do DevTools **e** espelhadas no mesmo arquivo via o comando
  `log_client_event` (`src/lib/clientLog.ts` → `log_client_event` em
  `lib.rs`), com o prefixo `client`.
- Para abrir a pasta sem precisar saber o caminho: ícone do Campfire na
  bandeja do Windows → **Abrir pasta de logs**.
- O DevTools (F12 / botão direito → Inspecionar) agora funciona também em
  build de release (`tauri`'s feature `devtools` habilitada no
  `Cargo.toml`), útil para olhar o console em tempo real além do arquivo.

Essas linhas existem só para diagnóstico local; nada é enviado ao servidor.

## Infraestrutura: ponto pendente

O template `infra/livekit/livekit.yaml` anuncia TURN/TLS na porta 5349 com
`external_tls: true`, mas o compose fornecido não contém um terminador TLS L4.
O Caddy configurado como proxy HTTP/WebSocket para 7880 não cumpre esse papel.
Pode existir um balanceador externo no ambiente real; é necessário confirmá-lo.

Sem esse componente, uma boa conexão de internet não garante recuperação em
redes que bloqueiam mídia UDP. Não basta abrir 5349: o endpoint anunciado precisa
realmente falar TLS com certificado válido para `LIVEKIT_DOMAIN`.

Alternativas de implantação (exigem escolher e configurar certificados/roteamento):

- Terminar TLS em um balanceador L4 e encaminhar TURN ao LiveKit, mantendo
  `external_tls: true`.
- Terminar TLS no próprio LiveKit, usando `external_tls: false`, `cert_file` e
  `key_file` montados e renovados com segurança.

Não foi alterado o roteamento nem reiniciado o servidor nesta correção.
Referências: [conexão e reconexão LiveKit](https://docs.livekit.io/intro/basics/connect/)
e [configuração oficial do servidor](https://github.com/livekit/livekit/blob/master/config-sample.yaml).

## Validação entre dois dispositivos

1. Compartilhar uma tela estática (texto) e depois vídeo em movimento, inicialmente
   em 720p/30 FPS. Testar navegador e captura nativa, com e sem áudio.
2. Interromper a rede de cada lado por alguns segundos e restaurá-la, tanto em DM
   quanto em canal de voz. A chamada deve reconectar e a tela já selecionada deve
   voltar sem clicar novamente em Assistir.
3. Repetir em 1080p, com o receptor em miniatura e em tela ampliada; observar CPU
   do emissor e do servidor, FPS, resolução e bitrate efetivamente enviados.
4. No Chromium, usar `chrome://webrtc-internals` para comparar perda de pacotes,
   RTT, `qualityLimitationReason`, frames codificados/descartados e o par ICE
   selecionado. Não compartilhar dumps sem remover identificadores/IPs/tokens.
5. Validar o fallback em uma rede de teste com UDP bloqueado, incluindo uma
   conexão forçada via relay. HTTPS/WebSocket funcionando não valida TURN.
6. Fechar a janela capturada e encerrar a chamada durante a captura: não devem
   permanecer gravador, áudio ou tracks ativos. Testar também ausência definitiva
   do outro participante e o encerramento após o prazo de tolerância.

Os testes automatizados cobrem regressões locais, não qualidade fim a fim nem
disponibilidade do TURN em produção. Rodar no diretório `client`:

```sh
npm run test:voice
npm run build
```
