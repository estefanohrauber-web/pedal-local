# Pedal Local — protótipo web (design)

Data: 2026-10-06
Status: aprovado para plano de implementação

## Objetivo

Validar a ideia de pedalar, numa bicicleta ergométrica em casa, uma rota real
que a pessoa conhece (o próprio bairro), sentindo subidas e descidas pela
velocidade virtual. O protótipo precisa responder três perguntas:

1. O app consegue ler os dados da bike do usuário (Winnek Sync, painel FitShow)?
2. Montar uma rota no bairro com relevo real funciona bem?
3. Pedalar essa rota é mais motivador do que só olhar números?

Nome "Pedal Local" é provisório.

## Público e plataforma

- Usuário de bike ergométrica/spinning popular no Brasil, celular Android.
- Web app aberto no **Chrome para Android** (Web Bluetooth). Também funciona no
  Chrome desktop com Bluetooth, útil para desenvolvimento.
- Interface em português do Brasil, unidades métricas (km/h, m, %, W, rpm).

## Escopo

### Dentro

1. **Conexão com a bike** via Web Bluetooth, com três fontes de dados:
   FTMS, FitShow e Simulada.
2. **Montar rota**: tocar pontos no mapa → rota pelas ruas → altimetria →
   perfil de relevo com inclinação por trecho.
3. **Pedalar a rota**: posição andando no mapa, gráfico de relevo com marcador,
   métricas grandes, avisos de subida/descida, tela sempre acesa.
4. **Rotas salvas** no aparelho (repetir percurso, funciona offline).
5. **Configurações**: peso do ciclista, modo de potência, calibração do estimador.

### Fora (fica para depois da validação)

Street View/fotos, login, ranking/social, histórico de treinos, exportar
FIT/GPX/Strava, controle de resistência (a bike do usuário tem ajuste manual),
publicação na Play Store, iOS.

## Arquitetura

HTML + CSS + JavaScript com módulos ES, **sem etapa de build**. Bibliotecas de
terceiros só por CDN: Leaflet (mapa). Gráfico de relevo desenhado em `<canvas>`
próprio (sem biblioteca).

Cada unidade abaixo tem uma responsabilidade e pode ser testada isoladamente.
As unidades puras (sem navegador) ficam livres de DOM e de `fetch` para rodar
nos testes com Node.

### 1. Fontes da bike (`src/bike/`)

Interface comum de todas as fontes:

```js
source.connect()        // Promise; pede o dispositivo e assina notificações
source.disconnect()
source.onData(cb)       // cb({ cadence, power, speed, timestamp })  — campos ausentes = null
source.onDisconnect(cb)
source.name             // "FTMS", "FitShow", "Simulada"
```

- **`ftms-parser.js`** (puro): decodifica a característica *Indoor Bike Data*
  (`0x2AD2`) do serviço *Fitness Machine* (`0x1826`) conforme os flags da
  especificação FTMS — velocidade instantânea, cadência (unidade 0,5 rpm),
  potência instantânea (W, com sinal), e pula corretamente os campos opcionais
  (velocidade média, cadência média, distância, nível de resistência, potência
  média, energia, FC, MET, tempo).
- **`ftms-source.js`**: `requestDevice` filtrando pelo serviço `0x1826`
  e também por prefixo de nome `FS-` (painéis FitShow), com
  `optionalServices: [0x1826, 0xfff0, 0x180a]`. Assina `0x2AD2`.
- **`fitshow-source.js`**: protocolo proprietário FitShow (serviço `0xFFF0`).
  **Item em aberto**: só será implementado se a inspeção com o nRF Connect
  mostrar que a bike não expõe `0x1826`. Referência de protocolo: implementação
  FitShow do projeto open source qdomyos-zwift. Até lá, o arquivo existe apenas
  se necessário — não criar stub vazio.
- **`sim-source.js`**: gera cadência e potência a cada 1 s com variação suave
  (ex.: 75–90 rpm, 120–200 W) e controles de "mais forte/mais fraco" na tela,
  para desenvolver e demonstrar sem bike.

### 2. Estimador de potência (`src/power.js`, puro)

Bikes populares costumam mandar só cadência, ou uma potência inventada.

- Modo `"bike"`: usa a potência recebida.
- Modo `"estimada"`: `P = cadência × (base + fator × nível)`, com
  `base = 0,6`, `fator = 0,25` como valores iniciais (nível 4 a 80 rpm ≈ 128 W),
  ambos ajustáveis em Configurações. `nível` = posição do botão de carga
  informada pelo usuário na tela de pedal (1 a 10, botões − / +).
- Modo `"auto"` (padrão): começa usando a potência da bike. Se durante 10 s
  seguidos com cadência > 0 todas as leituras de potência vierem nulas ou
  zero, troca para estimada até o fim da sessão e avisa na tela.
- Cadência 0 → potência 0 em qualquer modo.

### 3. Rota (`src/route/`)

- **`geo.js`** (puro): distância haversine, comprimento de polilinha,
  reamostragem da polilinha a cada **20 m**, interpolação de posição
  (lat/lon) para uma distância percorrida.
- **`routing.js`**: OSRM perfil bicicleta —
  `https://routing.openstreetmap.de/routed-bike/route/v1/driving/{lon,lat;...}?overview=full&geometries=geojson`.
  Recebe os pontos tocados, devolve a polilinha.
- **`elevation.js`**: Open-Meteo Elevation API —
  `https://api.open-meteo.com/v1/elevation?latitude=...&longitude=...`,
  em lotes de até 100 coordenadas.
- **`profile.js`** (puro): a partir dos pontos reamostrados + altitudes,
  suaviza altitudes com média móvel de ~100 m (5 amostras), calcula a
  inclinação de cada trecho de 20 m, limita a ±20 %, e fornece:
  - `gradeAt(distância)` — inclinação no ponto atual;
  - `lookahead(distância, 200)` — inclinação média dos próximos 200 m;
  - totais: distância, ganho e perda de elevação.

Formato de rota salva:

```json
{ "id": "...", "nome": "...", "criadaEm": "ISO",
  "waypoints": [[lat, lon], ...],
  "pontos": [[lat, lon, altitudeSuavizada], ...],   // a cada 20 m
  "distanciaM": 0, "ganhoM": 0, "perdaM": 0 }
```

### 4. Física (`src/physics.js`, puro)

Passo fixo de **0,25 s**. Constantes: g = 9,81; ρ = 1,225 kg/m³;
CdA = 0,32 m²; Crr = 0,005; massa = peso do ciclista (padrão 75 kg) + 10 kg
de bike. θ = atan(inclinação).

```
F_resist = m·g·(sen θ + Crr·cos θ) + ½·ρ·CdA·v²
F_motor  = P / max(v, 1 m/s)
a        = (F_motor − F_resist) / m
v        = clamp(v + a·dt, 0, 25 m/s)        // teto 90 km/h
```

Comportamentos esperados (viram testes):
- Plano, 150 W constante, 75 kg → velocidade de regime entre 28 e 32 km/h.
- Subida de 6 %, 150 W → entre 8 e 12 km/h.
- Descida de −5 %, 0 W, partindo de 0 → acelera e passa de 30 km/h.
- Plano, 0 W, partindo de 30 km/h → desacelera e fica abaixo de 12 km/h após 60 s.
- Velocidade nunca fica negativa (subida íngreme sem pedalar = para).

### 5. Sessão de pedal (`src/ride.js`, puro)

Máquina de estados: `pronto → pedalando ⇄ pausado → concluído`.
A cada leitura da bike guarda a potência atual; a cada passo de física avança
a distância percorrida pela rota. Expõe: distância, tempo em movimento,
velocidade, potência, cadência, inclinação atual, posição (lat/lon),
média de potência e velocidade. Ao chegar ao fim da rota → `concluído`.
Desconexão da bike → `pausado` automaticamente.

Avisos (via `lookahead` de 200 m), cada um só repete depois de passar do trecho:
- média ≥ 4 % → "Subida de X % em 200 m — aumente a carga".
- média ≤ −3 % → "Descida chegando — pode aliviar".

### 6. Interface (`src/ui/`, `index.html`, `styles.css`)

Três telas numa página só:

1. **Início**: conectar bike (FTMS / Simulada), lista de rotas salvas,
   botão "Nova rota", Configurações.
2. **Nova rota**: mapa Leaflet (OpenStreetMap) com geolocalização para
   centralizar no bairro; tocar adiciona ponto, botão desfazer, "Fechar volta"
   (volta ao ponto inicial); "Calcular" → mostra rota, distância, ganho de
   elevação e gráfico de relevo; "Salvar" com nome.
3. **Pedal**: mapa seguindo a posição; gráfico de relevo com marcador;
   métricas grandes (potência, rpm, velocidade, inclinação, distância, tempo);
   nível de carga − / +; aviso de subida; pausar/retomar; tela de resumo
   ao concluir.

Layout pensado para celular em pé (≥ 360 px de largura), fontes grandes para
ler pedalando. Tela mantida acesa com Screen Wake Lock API durante o pedal.

### 7. Armazenamento (`src/storage.js`)

`localStorage` com chaves `pedal-local:rotas` e `pedal-local:config`,
leituras e escritas em `try/catch`. Rotas salvas não precisam de internet
para serem pedaladas (só os blocos do mapa, que podem não aparecer offline —
o pedal continua funcionando sem o mapa de fundo).

## Tratamento de erros

| Situação | Comportamento |
|---|---|
| Navegador sem Web Bluetooth | Aviso "Abra no Chrome do Android"; modo Simulada disponível |
| Usuário cancela a escolha do dispositivo | Volta ao início sem erro |
| Bike não expõe FTMS | Mensagem pedindo o print do nRF Connect (enquanto FitShow não existir) |
| Bike desconecta no meio | Pausa, botão "Reconectar" |
| Sem internet ao calcular rota | "Sem conexão — não deu para traçar a rota" |
| OSRM não acha caminho | "Não encontrei caminho entre esses pontos" |
| Altimetria falha | Rota salva como plana, com aviso |
| `localStorage` indisponível | App funciona, rotas não ficam salvas, aviso |

## Testes

- Testes automáticos com `node --test` (Node 24, sem dependências) para as
  unidades puras: `ftms-parser`, `power`, `geo`, `profile`, `physics`, `ride`.
- O parser FTMS é testado com pacotes montados à mão cobrindo combinações de
  flags (só cadência; cadência + potência; com campos opcionais no meio).
- Teste manual no Chrome desktop em modo Simulada (montar rota, pedalar,
  avisos, pausa, conclusão) antes de enviar o link.
- Teste com a bike real feito pelo usuário à noite, no celular.

## Hospedagem

Web Bluetooth exige HTTPS. Padrão: **GitHub Pages** (gratuito, precisa de
conta do usuário no GitHub). Alternativa, se o usuário preferir não criar
conta: link temporário via Cloudflare Tunnel apontando para um servidor local.

## Estrutura de arquivos

```
index.html
styles.css
src/app.js               — liga telas, fontes e sessão
src/storage.js
src/power.js
src/physics.js
src/ride.js
src/bike/ftms-parser.js
src/bike/ftms-source.js
src/bike/sim-source.js
src/route/geo.js
src/route/routing.js
src/route/elevation.js
src/route/profile.js
src/ui/home.js
src/ui/route-editor.js
src/ui/ride-screen.js
src/ui/elevation-chart.js
tests/*.test.js
```

## Caminho depois do protótipo

Se a validação for positiva, reescrever em Kotlin Multiplatform ou Flutter.
As unidades puras (parser FTMS, potência, física, perfil de rota, sessão) são
a parte a ser portada quase literalmente.
