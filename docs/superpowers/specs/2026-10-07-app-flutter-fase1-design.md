# Pedal Local — App Flutter, Fase 1 (núcleo) — design

Data: 2026-10-07
Status: aprovado em conversa; aguardando revisão do documento

## Objetivo

Transformar o protótipo web validado (Winnek SYNC conectou por FTMS e a rota
do bairro funcionou) num app Flutter para Android, com a navegação e o visual
aprovados no canvas (Esqueleto C + Design 2, artboards E1–E8):
https://claude.ai/artifact/KPcPF4u4Ro3TSsiy3roqqw

A Fase 1 é o **núcleo**: tudo funciona no celular, sem servidor e sem conta.

## Fases

1. **Núcleo (este documento).**
2. Comunidade: servidor, contas, ranking do bairro, desafio do mês.
3. Extras: Strava, treinos estruturados, voz, tema escuro, mapa offline.

## Escopo da Fase 1

### Dentro

- Navegação de 5 abas: Início · Explorar · (Pedalar, botão central) · Treinos · Você.
- Conexão com a bike por FTMS (Bluetooth), bike simulada, reconexão automática.
- Potência da bike ou estimada pela cadência e pela carga (calibração manual).
- Criar rota: adicionar, arrastar, apagar e desfazer pontos; ida e volta; fechar volta;
  buscar endereço; distância e relevo ao vivo.
- Gerar volta automática de 5, 10 ou 20 km saindo de um ponto, com opção "mais subida".
- Instruções de virar na tela durante o pedal (sem voz).
- Pedalar rota, pedalar contra o fantasma (o seu recorde na rota) e pedal livre.
- Resumo do pedal, histórico, recorde por rota, meta semanal, totais e 3 conquistas locais.
- Ajustes: peso, modo de potência, calibração, meta semanal, “minha casa”.
- Tema claro do Design 2.

### Fora (aparece como "em breve" onde estava no canvas)

Ranking, desafio do mês, “pessoas no segmento”, aba Subidas/Desafios do Explorar,
Strava, treinos por intervalos, teste de calibração automático, voz, tema escuro,
mapa offline, conta e backup, protocolo FitShow proprietário, build de iPhone
(o código usa só pacotes compatíveis com iOS, mas só Android é compilado e testado).

## Repositório e ambiente

- Repositório `estefanohrauber-web/pedal-local`, clonado em `C:\dev\pedal-local`.
  O Android não compila em caminhos com acento ou espaço, por isso nada em Documentos.
- App Flutter em `app/`. Protótipo web continua na raiz (GitHub Pages).
- Flutter 3.47.6, Dart 3.13, Android SDK em `C:\dev\android-sdk`, `minSdk` 23 ou o mínimo
  exigido pelos pacotes, o que for maior.
- Pacote Android: `com.pedallocal.app`. Nome exibido: “Pedal Local”.
- Celular de teste: Samsung Galaxy S20 FE (SM-G780G), Android 13.

## Arquitetura

```
app/lib/
  main.dart, app.dart            — MaterialApp.router, tema, ProviderScope
  core/
    theme/                       — tokens do Design 2, ThemeData
    router/                      — go_router: StatefulShellRoute (5 abas) + telas cheias
    format/                      — números, km, tempo em pt-BR
    widgets/                     — cartões, chips, gráfico de relevo, barra de abas
  domain/                        — Dart puro, sem Flutter, sem rede, sem Bluetooth
    geo.dart                     — haversine, distâncias acumuladas, pointAt, resample(20 m),
                                   destinationPoint, projeção de ponto na linha
    profile.dart                 — suavização (5 amostras), inclinação ±20 %, lookahead, totais
    physics.dart                 — stepSpeed (passo 0,25 s)
    power.dart                   — estimatePower, PowerResolver (auto/bike/estimada)
    ftms_parser.dart             — Indoor Bike Data (0x2AD2)
    ride_session.dart            — estados, avanço, avisos, amostras de 1 s
    ghost.dart                   — diferença de tempo para o recorde
    instructions.dart            — manobras do Valhalla (já em pt-BR) → instruções com distância na rota
    loop_geometry.dart           — pontos do gerador de voltas e ajuste de raio
    stats.dart                   — semana (seg–dom), totais, conquistas, calorias
  bike/
    bike_source.dart             — interface
    ftms_source.dart             — universal_ble
    sim_source.dart              — bike simulada
    bike_controller.dart         — estado da conexão, última bike, reconexão
  data/
    db/                          — sqflite (SQLite): rotas, pedais, ajustes
    services/                    — routing e elevation (Valhalla), geocoding (Photon),
                                   tiles; cada um atrás de uma interface
    repositories/                — rotas, pedais, ajustes
    route_builder.dart           — trechos em cache → linha, relevo, instruções
    loop_generator.dart          — usa loop_geometry + routing + elevation
  features/
    inicio/ explorar/ criar_rota/ escolher_pedal/ pedalando/ resumo/ treinos/ voce/
```

Pacotes: `flutter_riverpod`, `go_router`, `universal_ble`, `flutter_map`,
`latlong2`, `sqflite`, `http`, `geolocator`,
`wakelock_plus`, `google_fonts` (Plus Jakarta Sans,
baixada na primeira abertura; empacotar em `assets` antes de publicar).

Regra de dependência: `features → data/bike → domain`. O `domain` não importa nada
das outras camadas.

## Tema (Design 2)

Fundo `#F4F6F5`; superfície `#FFFFFF`; borda `#E1E6E3`; texto `#14201A`;
texto secundário `#5A6660`; destaque `#138A52` (texto branco sobre ele);
destaque suave `#E3F4EA` / texto `#0E6B3F`; posição no mapa `#2F6FE4`;
aviso de subida fundo `#FFF1E0` / texto `#8A3C00`. Fonte Plus Jakarta Sans.
Cantos: cartões 20–22 px, botões em pílula. Alvos de toque ≥ 48 px.
Mapa: fundo `#EAF0EC`, ruas brancas, parques `#CFE8D6`, água `#CFE3F5`
(aplicado no provedor de mapas do lançamento; em desenvolvimento usa o estilo
padrão do OpenStreetMap).

## Telas (o que cada uma faz na Fase 1)

| Tela (canvas) | Fase 1 |
|---|---|
| E1 Início | Status da bike; meta da semana (real); rota favorita (estrela, senão a mais pedalada) com “Pedalar”; cartão “Comunidade: em breve” no lugar de desafio e ranking |
| E2 Explorar | Mapa com as suas rotas, cada uma na sua cor (guardada na rota; a nova pega a cor menos usada); tocar numa rota, no mapa ou na lista, a destaca por cima e apaga as outras; lista “Minhas rotas”; busca filtra as rotas; botões “Criar rota” e “Gerar volta”; chips Subidas e Desafios marcados “em breve” |
| E8 Criar rota | Editor completo (abaixo), relevo ao vivo, gerador, salvar com nome |
| E3 Escolher pedal | Seguir rota · Contra o fantasma (só se a rota tem recorde) · Pedal livre · Treino (“em breve”); status da bike; Começar |
| E4 Pedalando | Mapa seguindo a posição, instrução de virar, fantasma, aviso de subida, velocidade, watts, rpm, inclinação, tempo, relevo com marcador, carga − / +, pausar, encerrar. Pedal livre: mesma tela sem mapa, com gráfico de potência no tempo |
| E5 Resumo | Recorde (se houver), mapa, 6 números, meta da semana; “Enviar ao Strava” desabilitado com “em breve” |
| E6 Treinos | Pedal livre em destaque; sessões, calibração automática e planos “em breve” |
| E7 Você | Totais (km, subida comparada a uma montanha), km por semana (8 semanas), 3 conquistas, histórico, ajustes |

## Bike

```dart
abstract class BikeSource {
  Stream<BikeReading> get readings;      // cadence, power?, speed?, heartRate?, timestamp
  Stream<BikeConnection> get connection;  // desconectada | conectando | conectada | caiu
  Future<void> connect();
  Future<void> disconnect();
}
```

- Busca filtra pelo serviço FTMS `0x1826` e por nome `FS-`; opção “procurar todos os
  aparelhos”. Sem FTMS: mostra o diagnóstico (nome e serviços do aparelho).
- Lê `0x2AD2` com `ftms_parser`. Guarda o `remoteId` da última bike e reconecta
  sozinho ao abrir o app.
- Queda inesperada durante o pedal: pausa a sessão, tenta reconectar 3 vezes
  (2 s, 5 s, 10 s), depois mostra “Reconectar”.
- Sem leitura por 3 s: entradas zeradas (a bike para de mandar quando para de pedalar).
- Permissões Android: `BLUETOOTH_SCAN` (neverForLocation), `BLUETOOTH_CONNECT`,
  localização para Android ≤ 11 e para “minha localização” no mapa.

## Rotas

### Editor

- Estado: lista de pontos (waypoints) + pilha de desfazer (cópias da lista).
- Gestos: tocar no mapa adiciona no fim; arrastar move; toque longo apaga (com desfazer).
- A rota inteira vai num pedido só ao Valhalla (cada par de pontos vizinhos vira uma
  "perna"). Os servidores da FOSSGIS aceitam 1 pedido por segundo, então pedir
  trecho por trecho deixaria o editor lento.
- Ida e volta: acrescenta os pontos em ordem inversa (a volta é traçada de novo,
  não espelhada). Fechar volta: acrescenta o primeiro ponto no fim.
- A linha completa é reamostrada a 20 m; a altimetria vem do Valhalla `/height`
  (até 5000 pontos por pedido), na mesma fila de 1 pedido por segundo.
- Busca de endereço: Photon com viés pela localização atual; escolher um resultado
  centraliza o mapa e oferece “adicionar ponto aqui”.

### Gerador de voltas

Entrada: ponto de partida (minha casa, ou localização atual), distância alvo
D ∈ {5, 10, 20} km, `maisSubida`.

1. Para cada direção inicial θ (3 direções; 6 com `maisSubida`), monta um círculo
   que passa pela partida, com centro a `r` metros na direção θ,
   `r = D / (2π) × 0,75`; coloca 3 pontos no círculo a 90°, 180° e 270° da partida
   e fecha na partida.
2. Traça pelo Valhalla e mede o comprimento L. Se |L − D| > 10 % de D, multiplica
   `r` por D / L e repete (até 3 tentativas).
3. Com `maisSubida`, busca a altimetria dos candidatos e ordena por ganho por km;
   sem, ordena pela proximidade de D.
4. Mostra as 3 melhores com distância e subida reais. Escolher uma abre no editor.

Com 1 pedido por segundo, cada tentativa custa 1 s: mostrar o progresso enquanto gera.

A geometria (círculo, pontos, ajuste do raio) fica em `domain/loop_geometry.dart`
e é testada sem rede.

### Instruções de virar

- O Valhalla devolve as manobras já em português (`language: pt-BR`); as de todas as
  pernas são concatenadas, e a chegada dos pontos intermediários é descartada.
- Cada manobra é projetada na linha reamostrada para obter a distância ao longo da rota.
- Textos: “vire à direita/esquerda”, “mantenha-se à direita/esquerda”,
  “vire acentuadamente…”, “faça o retorno”, “siga em frente”,
  “na rotatória, pegue a Nª saída”, “você chegou”; com o nome da rua quando houver.
- No pedal, mostra a próxima manobra à frente e os metros que faltam.

### Formato da rota

`id`, `nome`, `criadaEm`, `origem` (manual | gerada), `favorita`,
`waypoints` [[lat, lon]], `pontos` [[lat, lon, altitudeSuavizada]] a cada 20 m,
`instrucoes` [{distanciaM, tipo, modificador, saida?, rua}],
`distanciaM`, `ganhoM`, `perdaM`.

## Pedal

- `ride_session` igual ao protótipo (estados pronto → pedalando ⇄ pausado → concluído;
  física de 0,25 s; avisos de subida ≥ 4 % e descida ≤ −3 % em 200 m), mais
  **amostras de 1 s**: tempo em movimento, distância, velocidade, potência, cadência, FC.
- Modos: `rota`, `fantasma`, `livre`. No livre não há perfil: a física roda no plano e
  a sessão não conclui sozinha (o usuário encerra).
- **Fantasma**: usa as amostras do pedal concluído mais rápido naquela rota.
  `diferença = tempoDoFantasma(distânciaAtual) − tempoAtual`
  (interpolação linear); positivo = à frente. O marcador do fantasma no mapa usa
  `distânciaDoFantasma(tempoAtual)`.
- Tela sempre acesa durante o pedal (`wakelock_plus`).
- O pedal em andamento é gravado no banco a cada 15 s; se o app fechar, fica um pedal
  “incompleto” no histórico com o que foi feito.
- Calorias: `kcal = energia mecânica (J) / 1000` (regra usual com ~24 % de eficiência).

## Dados (sqflite / SQLite)

- `routes`: colunas do formato acima; listas em JSON.
- `rides`: `id`, `routeId?`, `modo`, `inicio`, `tempoMovimentoS`, `distanciaM`,
  `potenciaMediaW`, `velocidadeMediaKmh`, `ganhoM`, `kcal`, `concluido`,
  `amostras` (BLOB com float32 compactados: t, dist, vel, pot, cad, fc).
- `settings`: chave-valor (pesoKg 75, modoPotencia auto, base 0,6, fator 0,25,
  cargaPadrao 4, metaSemanalKm 60, casa [lat, lon]?, ultimaBikeId?).
- Recorde da rota = menor `tempoMovimentoS` entre pedais concluídos da rota.
- Semana: segunda a domingo, fuso do celular.
- Conquistas (calculadas na hora): “Primeira subida” (primeiro pedal com ≥ 50 m de
  subida), “7 dias seguidos”, “100 km” (total).
- Comparação de montanha no Você: Pico da Bandeira (2.892 m) e Pico da Neblina
  (2.995 m); mostra quantas vezes o total subido equivale à mais próxima.

## Serviços externos

| Uso | Desenvolvimento / Fase 1 | Antes de publicar |
|---|---|---|
| Mapa | tiles do OpenStreetMap, com User-Agent do app | provedor com chave e cota grátis (ex.: MapTiler), estilo do Design 2 |
| Rotas e manobras | Valhalla `valhalla1.openstreetmap.de/route`, bicicleta com BR, estrada principal, ladeira e contramão liberadas | Valhalla próprio ou serviço com chave; a FOSSGIS recomenda não fixar a URL no app |
| Endereços | `photon.komoot.io` (uso justo) | idem |
| Altimetria | Valhalla `valhalla1.openstreetmap.de/height`, lotes de 5000 | idem |

Todas as chamadas identificam o app no User-Agent. Cada serviço tem interface
própria em `data/services/`. Regras da FOSSGIS para o Valhalla: no máximo 1 pedido
por segundo (fila única no app) e crédito do mapa com link para
`openstreetmap.org/fixthemap` (tocar no “© OpenStreetMap” do mapa).

## Erros

| Situação | Comportamento |
|---|---|
| Bluetooth desligado / permissão negada | Explica e oferece botão para as configurações |
| Bike não encontrada / sem FTMS | Diagnóstico com nome e serviços |
| Queda durante o pedal | Pausa, 3 tentativas automáticas, depois “Reconectar” |
| Sem internet no editor ou no gerador | “Sem conexão — não deu para traçar a rota” |
| Sem caminho entre os pontos | “Não encontrei caminho entre esses pontos” |
| Rota acima de 150 km (limite do Valhalla) | “A rota passou de 150 km. Use pontos mais próximos.” |
| Altimetria falha | Rota plana com aviso e botão “Tentar de novo” |
| Gerador fora de ±10 % | Mostra as melhores opções com a distância real |
| Sem internet no pedal | Pedal funciona; o fundo do mapa pode não carregar |
| App fechado no meio do pedal | Pedal incompleto salvo no histórico |

## Testes

- `domain/`: tradução dos 70 testes do protótipo + fantasma, instruções, geometria do
  gerador, estatísticas da semana e conquistas (`flutter test`).
- `data/`: serviços com cliente HTTP falso; banco SQLite em memória (sqflite_common_ffi); `route_builder`
  e `loop_generator` com serviços falsos.
- Widgets: Início, Escolher pedal e Pedalando renderizam com dados falsos.
- Manual no SM-G780G: bike simulada primeiro, depois a Winnek SYNC.

## Critérios de aceite

1. Conecta a Winnek SYNC por FTMS e reconecta sozinho ao reabrir o app.
2. Cria uma rota usando adicionar, arrastar, apagar, desfazer, ida e volta, fechar volta
   e busca de endereço; distância e relevo atualizam.
3. Gera voltas de 5, 10 e 20 km a partir de “minha casa”, cada uma a até ±10 % do alvo
   numa área urbana.
4. Pedala uma rota com instruções de virar, avisos de subida e fantasma; salva o resumo.
5. Pedal livre funciona e entra no histórico.
6. Meta semanal, totais e conquistas refletem os pedais salvos.
7. Desconectar a bike no meio do pedal pausa e reconecta.
8. Todos os testes automáticos passam e o app instala e roda no SM-G780G.

## Decisões tomadas ao planejar (2026-10-07)

- **Bluetooth: `universal_ble` em vez de `flutter_blue_plus`.** A versão 2 do
  flutter_blue_plus exige licença comercial paga para uso com fins lucrativos; a 1.x
  está parada desde 2024. O universal_ble é BSD-3, mantido e cobre Android e iOS.
- **Banco: `sqflite` em vez de `drift`.** Evita geração de código (build_runner);
  testes usam `sqflite_common_ffi` com banco em memória.
- **`wakelock_plus` 1.8.0** (a 1.8.1 conflita com o universal_ble por causa do `dbus`).
- **Fonte:** `google_fonts` baixa a Plus Jakarta Sans na primeira abertura; empacotar
  o arquivo da fonte em `assets` antes de publicar.
- A Fase 1 é executada em 3 planos: (1) fundação, bike e pedal livre; (2) rotas;
  (3) pedalar a rota, fantasma e estatísticas.

## Troca de serviço de rotas e altitude (2026-10-08)

Testando em Herval d'Oeste (SC), duas falhas apareceram com OSRM + Open-Meteo:

- **Altitude sumia em rotas acima de ~12 km.** O Open-Meteo conta cada ponto como um
  pedido (limite de 600 por minuto); com um ponto a cada 20 m, a rota estourava o
  limite (HTTP 429, "Minutely API request limit exceeded") e ficava plana.
- **O traçado fugia das BRs e estradas principais.** O perfil de bicicleta do OSRM
  proíbe vias `highway=trunk` (a BR-282 está marcada assim) e evita primary/secondary
  por segurança. Herval → Erval Velho: 22,7 km por estrada de chão, contra 13 km pela BR.

O Valhalla da FOSSGIS resolve as duas: bicicleta com `use_roads: 1`, `use_hills: 1`
e `ignore_oneways: true` (pedal virtual, sem trânsito) foi pela BR-282 (12,4 km), e o
`/height` devolveu 12 mil alturas num pedido. O relevo também é mais fiel: no mesmo
trecho de 11 km da SC-150, com a suavização de 100 m, o Valhalla soma 269 m de subida
contra 580 m do Open-Meteo, que vem em degraus de 90 m. O protótipo web continua no
OSRM + Open-Meteo.
