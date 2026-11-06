# Boneco que não para e botão que acompanha o relevo — correção

Data: 2026-11-06. Relato dos pedais na rota “Entre pontes” com a Winnek: o botão de peso só
pedia 0, 4 ou 5 voltas (muito tempo no 0); num morro o boneco ficou parado mesmo com a pessoa
pedalando no peso pedido; as alturas do relevo não parecem as reais.

## O que os dados mostraram

- **Boneco parado:** com o botão de peso, os watts são estimados pelo giro e pela posição do
  botão. Num morro forte e girando devagar, a estimativa dá poucos watts, e a física tratava a
  velocidade como no mínimo 1 m/s para calcular a força dos pedais: abaixo disso a força não
  vencia o morro e o boneco ficava parado ou voltava.
- **0, 4 e 5 voltas:** o botão só mudava nos avisos. Subida pedia `posicaoPara(media)` (a
  média dos 200 m, que no Entre pontes dá 4 ou 5) e descida pedia sempre 0. Fora dos avisos,
  nada: o 0 da descida ficava até a próxima subida, inclusive no plano.
- **Relevo:** comparado ao Google, o perfil do app tem uns 50 m de subida por volta contra 31 m
  do Google, com ondinhas de ±5 m que não existem na beira-rio. O Valhalla cru (101 m), o
  ASTER (138 m) e o Copernicus (245 m) exageram mais ainda.

## Correções

- **Pedalando, o boneco não para:** `Physics.step` põe um piso na velocidade enquanto há
  watts: a velocidade em que esses watts vencem o morro (watts ÷ força do morro), se for menor
  que 1 m/s. Num morro de 11 % com 83 W o boneco sobe a uns 3 km/h em vez de parar. Parou de
  pedalar, a física é a de sempre.
- **Posição no relevo** (`BotaoPeso.posicaoNoRelevo`): no plano, um quarto do limite (2 voltas
  na Winnek, limite 9); na subida, `posicaoPara(inclinação)`, nunca abaixo do plano; em
  descida de 1,5 % ou mais, o mais leve.
- **Guia do botão** (`GuiaBotao`, só em rota com botão calibrado, sem fantasma):
  - pesa olhando a rampa mais forte entre os 200 m à frente e os 100 m em volta;
  - só alivia quando os últimos 40 m, os 200 m à frente e toda rampa de 200 m que começa nos
    próximos 200 m já aliviaram (não alivia antes do topo);
  - a mudança precisa ser pedida por 30 m antes de falar, e entre uma fala e outra há pelo
    menos 150 m (o começo conta como uma: dá para aquecer no mais leve);
  - voltar só uma volta logo depois de mudar no sentido contrário é soluço do relevo: não fala;
  - se um aviso de subida ou descida vai sair nos próximos 40 m, espera o aviso;
  - frases: “Trecho plano: gire o botão mais duas voltas.”, “Subida de 3 por cento: gire o
    botão mais uma volta.”, “Trecho mais leve: volte o botão duas voltas.”, “Descida: volte o
    botão 5 voltas.”; na tela, uma faixa com ícone de ajuste.
- **Nos avisos** (`GuiaBotao.noAviso`): subida pesa para a rampa que o aviso fala (a mais forte
  dos 100 m) e o relevo perto; descida só alivia se o topo já passou (senão fala só “Descida
  chegando.”). A mudança no aviso conta para o intervalo das falas.

Simulação de uma volta do Entre pontes (80 kg, giro 75, watts estimados pelo botão):

| | Antes | Depois |
|---|---|---|
| Tempo da volta | 9,9 min | 9,3 min |
| Menor velocidade | 4,6 km/h | 5,9 km/h |
| Tempo em cada posição | 0: 50 %, 4: 8 %, 5: 42 % | 0: 8 %, 2: 35 %, 3: 28 %, 5: 8 %, 6: 10 %, 8: 11 % |
| Instruções do botão | 5 | 12 |

## Fica para depois

- **Relevo do terreno:** suavizar mais forte o relevo do Valhalla (as ondinhas de ±5 m) ou
  achatar a beira-rio; o Google é a referência que mais faz sentido (↑31 m, 521–551 m, plano
  de 0,8 a 2,5 km e uma subida de uns 6 % de 2,55 a 2,98 km).
- Testar no pedal de verdade se 150 m entre as falas é bom ou se pede mais (ou menos).

## Verificação

472 testes automáticos (3 da física, 12 do guia, 2 do controlador novos). Simulação da volta
do Entre pontes com o perfil salvo da rota. Ainda não instalado no celular.
