# Relevo alisado em sino de 60 m — correção

Data: 2026-11-06. Continuação de `2026-11-06-boneco-e-botao-design.md`: o relevo do Entre
pontes tem um sobe e desce que a rua não tem. Fica o Valhalla como fonte da altitude; o pedido é
arrumar o relevo que vem dele.

## O que os dados mostraram

- O Valhalla dá a altitude em metros inteiros, a cada 20 m, e erra uns ±5 m de um ponto para
  outro (árvores, prédios, a encosta ao lado da rua). A média de 5 pontos (80 m) não bastava:
  na beira-rio plana sobrava uma lombada que virava aviso de “Subida de 6 %” perto de 1,4 km.
- Alisar mais com média simples (11 a 15 pontos) apaga também as ladeiras de verdade. O sino
  puro (gaussiano) achata as pontas: uma rota que começa numa ladeira perde a ladeira.

## Correção

- `smoothElevations(dists, alts)`: em cada ponto, a reta que melhor passa pelos vizinhos até
  180 m antes e depois, com peso em sino (σ = 60 m). No meio da rota é a média em sino; perto
  das pontas, a reta mantém a ladeira (rampa reta continua reta).
- `reliefVersion` passa a 3: as rotas salvas são refeitas ao abrir o app com internet (nome,
  cor e pontos ficam; só o relevo muda).

Subida total por volta (relevo refeito a partir das alturas do Valhalla):

| Rota | Antes (média de 5) | Depois (sino de 60 m) |
|---|---|---|
| Entre pontes | ↑50 m | ↑40 m |
| Casa trabalho | ↑339 m | ↑318 m |
| Joaçaba a Luzerna | ↑141 m | ↑104 m |
| Volta Sede Belém | ↑805 m | ↑685 m |

As ladeiras de verdade ficam: a rampa de 200 m mais forte da Casa trabalho vai de 12,2 % para
11,6 %. No Entre pontes, a diferença para o Google cai de 3,7 m para 3,4 m em média e o aviso
falso de 6 % perto de 1,4 km some.

Simulação de uma volta do Entre pontes com o guia do botão (80 kg, giro 75, Winnek):

| | Relevo antes | Relevo alisado |
|---|---|---|
| Tempo da volta | 9,3 min | 9,5 min |
| Menor velocidade | 5,9 km/h | 7,8 km/h |
| Avisos de subida | 2 (6 % e 9 %) | 1 (6 %) |
| Instruções do botão | 12 | 9 |
| Tempo em cada posição | 0: 8 %, 2: 35 %, 3: 28 %, 5: 8 %, 6: 10 %, 8: 11 % | 0: 8 %, 2: 29 %, 3: 49 %, 4: 3 %, 5: 11 % |

## Fica para depois

- No Entre pontes o modelo do terreno ainda começa a subida uns 400 m antes do Google (perto de
  1,96 km em vez de 2,4 km) e sobra uma lombada de uns 7 m entre 1,45 e 1,7 km que o Google
  não mostra. Alisar não resolve: é o dado. Resolveria uma fonte de altitude melhor ou ajustar
  a rota à mão.

## Verificação

474 testes automáticos (4 novos do alisamento). Relevo das 4 rotas refeito fora do app com as
alturas do Valhalla e comparado ao Google no Entre pontes.
