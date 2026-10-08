# Sentido, voltas e histórico com mapa — desenho

Pedido do usuário (2026-10-08): escolher o sentido e o começo da rota antes de pedalar,
dar várias voltas numa rota fechada (com margem para fechar a volta), ver o mapa do
pedal no histórico pintado por velocidade/potência, e todas as melhorias sugeridas para
a aba Você. A parte de **potência** fica só em pesquisa e explicação (o usuário decide depois).

## 1. Preparar o pedal (antes de começar)

“Pedalar esta rota” (Explorar e Início) abre a tela **Preparar pedal** (`/rota/:id/preparar`):

- Mapa com a rota, setas de sentido, marca de **início** (e de **fim** quando não é volta).
- Tipo detectado: **volta fechada** quando o fim fica a até 50 m do início; senão **ida**
  (de um ponto a outro).
- **Ida**: botão “Inverter sentido” (o fim vira o começo; subida e descida trocam).
- **Volta fechada**:
  - sentido **horário / anti-horário** (calculado pela área com sinal do contorno);
  - **começo**: tocar no mapa escolhe o ponto da rota mais perto; “Começo original” desfaz;
  - aviso: “Ao completar a volta, o pedal segue para a próxima. Encerre quando quiser.”
- Distância, subida, descida e gráfico de relevo já no sentido e começo escolhidos.
- “Começar pedal” (sem bike conectada, leva para conectar antes).

A variante é aplicada aos pontos da rota (a cada 20 m):
- girar o começo: tira o ponto final repetido (se a até 25 m do início), gira a lista para
  começar no ponto escolhido e fecha de novo nele;
- inverter: lista ao contrário.

O pedal recebe `RideTarget(routeId, reversed, startIndex)`; a URL leva `?sentido=inverso&inicio=N`.

## 2. Voltas

- Numa volta fechada o terreno se repete (`LoopTerrain`): o pedal não conclui sozinho.
- Ao completar uma volta: faixa “Volta N concluída em mm:ss” por 8 s; cabeçalho mostra
  “Volta N · x km de y km”.
- **Encerrar** com `voltas ≥ 1`: se o que passou da última volta é até a **margem**
  (padrão 3 %, ajustável de 0 a 10 % em Ajustes) da volta, esse pedaço é **descartado**:
  distância, tempo, amostras, potência média, subida e kcal voltam para o fechamento da volta.
  Acima da margem, guarda tudo (“2 voltas + 0,8 km”).
- Ida: conclui no fim, como hoje (1 volta).
- O título do resumo passa a depender das voltas: “Rota concluída!” só com `voltas ≥ 1`
  (antes, encerrar no meio também dizia “concluída”).

## 3. Pedal guardado (banco versão 4)

`rides` ganha: `laps` (voltas completas), `loop` (0/1), `reversed` (0/1),
`trimmed_m` (metros descartados pela margem) e `track` (BLOB float32 lat, lon, alt
da rota pedalada, uma volta, já no sentido e começo escolhidos). Com o `track`, o mapa do
pedal continua existindo mesmo se a rota for apagada ou mudar.
Migração: pedais antigos de rota recebem o `track` da rota (sentido original) e
`laps = 1` quando concluídos com a distância da rota.
`settings` ganha `nome` e `margemVolta` (0,03).

## 4. Resumo e análise do pedal (histórico)

- Cabeçalho: título, rota, data; “2 voltas · anti-horário” quando couber.
- **Mapa colorido**: o caminho pintado pela métrica escolhida — **Velocidade, Potência,
  Cadência, Inclinação** (e FC quando houver). Escala do **azul (menor) ao vermelho
  (maior)** passando por ciano, verde e amarelo; limites nos percentis 5 e 95 para um
  pico isolado não apagar o resto; média móvel de 5 s antes de pintar. Legenda com
  mínimo e máximo. Marcas de início e fim.
- **Gráfico da métrica pela distância**, com o mesmo degradê. Arrastar o dedo no gráfico
  mostra o valor naquele ponto e uma bolinha no mapa.
- Várias voltas: escolha da volta (1, 2, 3…) e lista de tempos por volta.
- Números: km, tempo, km/h média, watts média, subida, kcal, velocidade máxima,
  potência máxima, cadência média.
- **Comparação**: tempo médio por volta contra o pedal anterior na mesma rota e no
  mesmo sentido; “Seu melhor tempo nesta rota!” quando for o melhor.
- “Apagar este pedal” (com confirmação). Aberto pelo histórico tem botão de voltar;
  logo após o pedal mantém “Concluir”.
- Pedal livre: sem mapa; gráfico e números.

## 5. Aba Você

- Cabeçalho com o **nome** (“Olá, Fulano”) — tocar abre Ajustes. Início também usa o nome.
- **Esta semana** (segunda a domingo): km com barra da **meta semanal**, pedais, tempo, subida.
- **Desde o começo**: km, tempo, subida, pedais e a comparação com o Pico da Bandeira
  (2.892 m) / Pico da Neblina (2.995 m).
- Histórico **agrupado por semana** (“Esta semana”, “Semana passada”, “Semana de dd/mm”),
  com o total de km do grupo. Cartão: desenho do caminho na cor da rota, nome, data,
  km, tempo, watts e subida, selo de voltas e de incompleto.

## 6. Ajustes

Seções com explicação curta em cada item: Perfil (nome), Corpo (peso), Meta semanal,
Voltas (margem), Potência (modos explicados; aviso em “Da bike”), Carga inicial,
**Avançado** fechado por padrão (base e fator), e **Dados da bike**: tela que mostra ao vivo
o que a bike envia (cadência, potência, nível de resistência, velocidade, FC) para
descobrir se a Winnek manda potência ou o nível do botão. O parser FTMS passa a ler o
nível de resistência (antes era pulado).

A calibração guiada fica para depois da decisão sobre potência.
