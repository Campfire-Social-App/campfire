# Campfire — serviço de bots

Um processo à parte, no mesmo compose, que hospeda os bots do servidor. Hoje há
um: o **yt-dlp**, que toca música no canal de voz de quem pediu.

Um bot aqui não é nada de especial do ponto de vista do servidor: é uma conta
como qualquer outra, que loga, mantém o WebSocket do gateway aberto (é isso que
o deixa **online** na lista de membros) e publica no LiveKit com o mesmo token
que um cliente humano pediria. O que o distingue é a flag `is_bot` na conta, que
os clients usam para desenhar o selo **BOT**.

## Como um comando chega aqui

```
cliente ──JWT──> server:8000  POST /api/commands
                     │  valida o JWT, o canal e o timeout
                     │  resolve o canal de voz do autor no voice_state dele
                     └──X-Campfire-Bot-Secret──> bots:8100  POST /commands/play
```

Este serviço **não é publicado pelo Caddy** e não conhece o `JWT_SECRET`. Ele
confia no que o servidor conta sobre quem pediu — inclusive em que call a pessoa
está — porque só o servidor tem essa informação de primeira mão. O
`X-Campfire-Bot-Secret` é a segunda linha, para um container qualquer na mesma
rede não conseguir mandar o bot entrar numa call.

Erro que dá para saber na hora (não está numa call, faltou argumento, fila
vazia) volta como HTTP 4xx e o cliente mostra um toast. Resultado que só existe
depois (faixa resolvida, começou a tocar, o download falhou) o bot posta **no
canal**, como mensagem dele.

## Os comandos do yt-dlp

| Comando | Precisa estar em call? | O que faz |
| :-- | :-- | :-- |
| `/play <url ou busca>` | sim | Resolve e põe na fila. Se nada tocava, entra na call e começa. |
| `/pause` | sim | Pausa a faixa atual. |
| `/resume` | sim | Retoma. |
| `/skip` | sim | Pula para a próxima. |
| `/stop` | sim | Limpa a fila e sai da call. |
| `/queue` | não | Lista a fila no chat. |

Cada canal de voz tem sua própria fila: dois grupos em duas calls não se
atrapalham.

## O caminho do áudio

`yt-dlp` resolve a busca ou a URL num endereço de stream direto; o `ffmpeg`
decodifica esse stream para PCM cru (48 kHz, estéreo, s16le) na saída padrão; e
o laço em [`app/bots/ytdlp/player.py`](app/bots/ytdlp/player.py) lê isso em
quadros de 10 ms e entrega cada um ao `AudioSource` do LiveKit. O
`capture_frame` já se ritma contra a fila interna da fonte, então esperar por
ele *é* o relógio — não há `sleep` nenhum no laço.

O `/pause` limpa um `asyncio.Event` que o laço espera antes de cada quadro. O
ffmpeg trava sozinho no próprio pipe quando o buffer enche, então não há o que
descartar no `/resume`.

A faixa é publicada como `SOURCE_MICROPHONE` de propósito: assim ela cai no
mesmo lugar que os clients já desenham, inclusive o controle de volume por
participante — que é exatamente o controle que se quer num bot de música.

## Rodando

Precisa de **ffmpeg** no PATH (a imagem Docker já o instala).

```bash
poetry install
BOT_PASSWORD=... BOTS_SHARED_SECRET=... poetry run uvicorn app.main:app --port 8100

poetry run pytest -q      # não toca em rede nem em ffmpeg
poetry run ruff check .
```

Variáveis em [`.env.example`](../.env.example) na raiz do repositório. A conta do
bot é criada pelo próprio servidor no boot, a partir de `BOT_USERNAME` e
`BOT_PASSWORD` — os dois lados leem do mesmo `.env`.

Sem `BOT_PASSWORD` ou `BOTS_SHARED_SECRET` o serviço **sobe assim mesmo**, sem
bot nenhum, e diz isso no log. O `GET /api/commands` devolve lista vazia, que é
o mesmo caminho de um deploy que não tem `bots/` — os clients simplesmente não
abrem o menu de `/`. É de propósito: um serviço novo e opcional não pode fazer
o deploy do chat e da voz falhar por causa de um `.env` desatualizado.

`LIVEKIT_URL_OVERRIDE` normalmente fica vazio: o endereço do SFU vem no mesmo
`POST /api/voice/{id}/token` que os clients usam. Só preencha (com
`ws://livekit:7880`) se a VPS não rotear o próprio IP público de volta para
dentro.

## Quando o YouTube pede login

O YouTube decide **por IP de origem** se acredita que quem chama é gente. Um
endereço de datacenter cai no `Sign in to confirm you're not a bot` muito mais
facilmente que um residencial — o que significa que o mesmo build resolve sem
reclamar na sua máquina e falha na VPS, e que o problema não é reproduzível
onde ele não acontece.

Duas saídas, em ordem de custo:

**1. Trocar o player client.** `YTDLP_PLAYER_CLIENTS` recebe uma lista separada
por vírgula. Numa varredura feita de um IP limpo, só três resolvem sozinhos:

| client | resolve | precisa de PO token |
| :-- | :-- | :-- |
| `visionos` | sim | **não** |
| `android_vr` | sim | sim |
| `android` | sim | sim |

Comece por `visionos`, que é o único que junta as duas coisas. Os demais
(`tv`, `web`, `web_embedded`, `mweb`, `ios`…) falharam já na resolução, então
não adianta tentá-los às cegas. Isso muda com o tempo: se nenhum funcionar,
vale repetir a varredura antes de partir para os cookies.

**2. Cookies.** `YTDLP_COOKIES_FILE` aponta para um arquivo em formato
Netscape. Em produção ele vai em `infra/bots-secrets/`, montado em `/run/bots`.
É a saída confiável, ao custo de amarrar uma conta Google ao bot — **use uma
descartável, nunca a sua**.

Se nem isso bastar, o passo seguinte é um provedor de PO token
(`bgutil-ytdlp-pot-provider`), que é mais um serviço no compose. Não está aqui
porque é bastante peso para um problema que os dois de cima costumam resolver.

## Adicionando outro bot

1. Uma pasta em `app/bots/<nome>/` com uma classe que satisfaça o `Bot` de
   [`app/core/registry.py`](app/core/registry.py): `commands()`, `start()`,
   `stop()` e `run(command, context)`.
2. Um `registry.register(...)` em [`app/main.py`](app/main.py).

Os nomes de comando são globais entre os bots — registrar dois `/play` levanta
erro no boot em vez de deixar a ambiguidade passar. O `GET /commands` junta os
descritores de todos, e é ele que alimenta o menu de `/` nos dois clients.
