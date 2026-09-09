# Criação de decorações de perfil

Esta é a especificação pública para criar packs de borda compatíveis com o Profile Card do Campfire. O card possui **300 px de largura** e altura fluida conforme as informações inseridas; **300 × 454 px** é a referência para criação da arte. O avatar possui **64 × 64 px**.

## Arquivos do pack

| Arquivo | Canvas de criação | Exibição | Formatos |
|---|---:|---:|---|
| Moldura do card | 600 × 908 px | 300 × 454 px | PNG ou WebP |
| Ornamento do topo | 600 × 128 px | 300 × 64 px | PNG, WebP ou GIF |
| Moldura do avatar | 384 × 384 px | 96 × 96 px | PNG, WebP ou GIF |
| Placa de identificação | 456 × 80 px | 228 × 40 px | PNG, WebP ou GIF |

Na tela **Profile → Your decoration assets**, o upload do usuário aceita PNG e GIF. WebP continua reservado aos packs produzidos pelo pipeline interno.

O frame estrutural usa 9-slice `160 32 64 32` (topo, direita, base e esquerda). Isso preserva as bordas quando o conteúdo muda a altura. Mantenha essa moldura estática e anime somente o ornamento de topo, o avatar ou a placa, sempre com poster estático. Packs legados registrados podem usar `512 × 768` com slices `150 55 70 55`.

## Áreas protegidas

- Card: a moldura deve coincidir com a caixa do card, sem `inset` negativo. Laterais podem ocupar até 12 px internos e a base até 24 px internos.
- Topo: toda a arte deve permanecer dentro do canvas de 600 × 128. Ela será reduzida exatamente para 300 × 64.
- Avatar: o círculo da foto ocupa `x=64`, `y=64`, `256 × 256` no canvas. A abertura transparente deve ter no mínimo 264 px de diâmetro.
- O indicador de presença fica no quadrante inferior direito do avatar e é renderizado acima da decoração.
- Placa: a metade esquerda (`x=0..227`) permanece integralmente transparente. A arte ocupa somente a metade direita (`x=228..455`), atrás da terminação do nome e do selo, sem retângulo ou fundo opaco. Avatar, nome e selo nunca são rasterizados no asset.

## Animações

- GIF é aceito no topo, no avatar e na placa; a interface cria automaticamente um poster PNG para movimento reduzido.
- Máximo de 15 fps, 6 segundos e 90 frames por loop.
- Máximo de 5 MiB para o topo, 3 MiB para o avatar e 4 MiB para a placa.
- Todo asset animado precisa de um poster PNG/WebP estático para `prefers-reduced-motion`.
- Evite flashes acima de 3 Hz.

## Segurança e publicação

O servidor valida a assinatura real e decodifica todos os frames, confere dimensões, duração, transparência, pixels totais e áreas protegidas antes de armazenar o arquivo. Não são aceitos SVG, HTML, CSS, JavaScript, URLs externas ou arquivos que cubram as áreas protegidas.

Manifesto esperado pelo cliente:

```json
{
  "version": 1,
  "cardFrame": {
    "src": "/decorations/my-pack-card-frame.webp",
    "format": "webp",
    "sourceSize": [600, 908],
    "slices": [160, 32, 64, 32],
    "layout": "flush"
  },
  "cardTop": {
    "src": "/decorations/my-pack-card-top.gif",
    "posterSrc": "/decorations/my-pack-card-top-poster.webp",
    "format": "gif",
    "sourceSize": [600, 128],
    "animated": true
  },
  "avatarFrame": {
    "src": "/decorations/my-pack-avatar.gif",
    "posterSrc": "/decorations/my-pack-avatar-poster.webp",
    "format": "gif",
    "sourceSize": [384, 384],
    "animated": true
  },
  "identityPlate": {
    "src": "/decorations/my-pack-identity-plate.webp",
    "format": "webp",
    "sourceSize": [456, 80]
  }
}
```

Cada usuário pode manter um asset personalizado por papel. O upload novo substitui o anterior somente naquele papel; a seleção `Custom` continua independente para card, avatar e placa. Ao remover um asset ativo, o papel correspondente volta para `None`. Os arquivos são servidos pela API com `nosniff`, e o cliente respeita `prefers-reduced-motion` usando o poster gerado para GIF.
