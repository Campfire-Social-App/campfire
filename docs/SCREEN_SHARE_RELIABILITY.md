# Transmissão de tela: estabilidade e validação

## Comparação com o Discord

O Campfire e o Discord usam WebRTC e encaminham a mídia por um servidor, em vez
de criar uma conexão direta entre quem transmite e cada espectador. O Campfire
usa LiveKit como SFU. No navegador, o caminho é `getDisplayMedia()` →
codificador WebRTC → LiveKit.

No aplicativo Tauri, o seletor e a captura são sempre nativos. A detecção usa a
API oficial `isTauri()`; `getDisplayMedia()` fica restrito à versão web e também
é bloqueado caso algum fluxo tente chamá-lo dentro do cliente.

No Windows, a captura nativa roda inteira na GPU: Windows.Graphics.Capture
entrega uma textura D3D11, o video processor do D3D11 escala e converte para
NV12, e um transform do Media Foundation codifica H.264 por hardware — o pixel
nunca passa pela CPU antes de estar comprimido. Só o bitstream atravessa a IPC
do Tauri, onde o WebCodecs (`VideoDecoder`) o decodifica por hardware e entrega
os frames a um track generator, que o LiveKit publica como qualquer outra
faixa. Isso existe porque o caminho anterior — RGBA → resize → JPEG na CPU —
foi medido em 65-99 ms por frame em produção, limitando a transmissão a 10-13
FPS independentemente do que o usuário pedia. O caminho antigo permanece como
fallback automático (ver "Fallback" abaixo).

O Discord documenta código próprio de captura e codificação integrado às APIs do
sistema e aos drivers de vídeo, com codificação por hardware quando disponível,
e usa WebRTC para transporte. A diferença que resta em relação a ele é o encode
final: no Campfire o bitstream intermediário é decodificado e recodificado pelo
WebRTC do Chromium, enquanto o Discord entrega o quadro codificado direto ao
transporte. O intermediário roda com bitrate alto (25-50 Mbps, já que a IPC é
local), o que torna a perda da dupla compressão desprezível; o custo é ~1-2
frames de latência. Referências oficiais: [visão geral do Go Live](https://discord.com/blog/how-it-all-goes-live-an-overview-of-discords-streaming-technology)
e [correções de FPS e encoder](https://discord.com/blog/from-blocky-to-brilliant-improving-video-quality-on-discord-go-live-on-amd-gpus).

### Fallback

A pipeline antiga (xcap → RGBA → JPEG → canvas) continua no código e é usada
automaticamente, sem opção na interface, quando o caminho GPU não inicializa:
sem encoder H.264 de hardware (VM, GPU antiga, driver quebrado), falha de
D3D11/Media Foundation, ou fora do Windows. O motivo vai para o log como
`[capture:gpu] ... unavailable`. A troca só acontece antes do primeiro frame —
depois disso o frontend já configurou um decoder para o stream H.264, e mandar
JPEG seria pior que falhar. O frontend reconhece qual pipeline recebeu pelo
cabeçalho `CFV1` dos quadros do caminho GPU (JPEG começa com o próprio marcador),
e escolhe o sink correspondente.

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

1. **Rust, captura/encode** (`src-tauri/src/capture.rs` e
   `src-tauri/src/capture/gpu_win.rs`) — via `log::info!`.
   No caminho GPU, as linhas `[capture:gpu]` trazem `sent_fps`, `keyframes`,
   `au_bytes_avg` (tamanho médio do access unit), `dropped_stale` (frames do
   pool descartados por já estarem obsoletos — sempre **antes** do encode),
   `starved` (o encoder pediu quadro e a captura não tinha nenhum),
   `scale_avg_ms` (VideoProcessorBlt), `encode_avg_ms`/`encode_max_ms`
   (latência submit→saída da MFT) e `ipc_avg_ms`/`ipc_max_ms`. Na inicialização
   há também uma linha com `encoder=` (nome amigável da MFT, que revela
   NVENC/QuickSync/AMF) e `tuned=` (quais ajustes de `ICodecAPI` o driver
   aceitou — varia por fornecedor).
   No caminho de fallback, as linhas `[capture:screen]`/`[capture:window]`
   seguem com os campos antigos: `produced_fps`, `sent_fps`, `coalesced`,
   `dropped_interval`, `dropped_backpressure`, `encode_avg_ms` (resize + JPEG
   + IPC) e `recv_gap_avg_ms`/`grab_avg_ms`.
2. **WebView, decodificação** (`src/lib/screenCapture.ts`). Linhas
   `[screen-share]` trazem `receivedFps` (quanto chega via IPC),
   `processedFps` (quanto chega ao track), `sink` (qual implementação foi
   escolhida: `video-track-generator`, `media-stream-track-generator` ou
   `canvas`), `codec`, `decodeAvgMs`/`decodeMaxMs`, `decodeQueue`, `keyWaits`
   (quadros descartados à espera de um keyframe depois de um reset) e
   `decoderErrors`. `sink=canvas` com `codec` H.264 significa que o track
   generator não estava disponível e sobrou um `drawImage` por frame — vale
   medir, mas ainda é melhor que o JPEG.
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
