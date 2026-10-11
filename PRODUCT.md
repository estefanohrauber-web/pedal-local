# Product

<!-- impeccable:product-schema 1 -->

## Platform

android

## Users
Duas pessoas no mesmo app (confirmado pelo dono em 11/10/2026):
- **Quem só quer pedalar:** tem uma bike ergométrica em casa e pedala por saúde e diversão, sem
  precisar entender de watts.
- **Quem treina:** segue metas de potência, FTP e planos de semanas.
O app deve ser simples para o primeiro e ter o detalhe técnico à mão para o segundo. O dono do
projeto pedala à noite, em casa, e não é programador.

## Product Purpose
Pedalar, numa bike ergométrica em casa, rotas reais do próprio bairro: o app lê a bike pelo
Bluetooth (FTMS), traça a rota pelas ruas com o relevo de verdade e faz a velocidade cair nas
subidas e subir nas descidas. Também tem treinos com metas de potência, planos, teste de FTP e um
editor de treinos. Sucesso: pedalar sem pensar no app, vendo o essencial de relance.

## Positioning
O trajeto é o do seu bairro, com o relevo real, numa bike barata de casa, mesmo sem controle de
resistência (o app guia pela voz).

## Operating Context
- O celular fica **no suporte do guidão**, a uns 50 cm do rosto, em pé (retrato), enquanto a
  pessoa pedala, sua e respira forte: leitura de relance, toques raros e grandes.
- Durante o pedal, **sempre à vista:** mapa, terreno (subida à frente), tempo, distância (atual e
  total, com barra de progresso), velocidade, giro (rpm) e potência. Um botão mostra **mais dados**
  para quem quiser.
- Bike de teste: Winnek SYNC 2151 (FitShow). Manda giro, watts, velocidade, distância, calorias e
  tempo, mas os watts saem só do giro: o botão de peso (manual) não entra na conta, e ela dorme
  1 minuto depois que a pessoa para de pedalar.
- O pedal acontece à noite, dentro de casa.

## Capabilities and Constraints
- Flutter 3.47 / Dart 3.13, só Android; banco local (SQLite), mapas OpenStreetMap, rotas e relevo
  pelo Valhalla, voz pelo TTS do Android.
- 5 abas: Início, Explorar, botão de pedalar, Treinos, Você.
- Os dados do usuário ficam só no celular (backup em nuvem está planejado, ainda não existe).
- Termos usados no app: pedal, rota, volta, giro, potência, carga, FTP, fantasma, treino.

## Brand Commitments
- Nome **Pedalaqui** (desde 9/10/2026); logo: uma rota que vira um pino de mapa, verde `#138A52`
  com a bolinha amarela `#F6C445`; nome em Plus Jakarta Sans ExtraBold. O dono aprovou a logo
  como está (10/10/2026).
- Tudo em português do Brasil, linguagem simples, sem jargão.

## Evidence on Hand
- Rotas reais do dono: “Entre pontes” (3,2 km) e “Casa trabalho” (9,6 km).
- Pedal real com a Winnek em 10/10/2026: 47–87 rpm, 100–264 W, 2,5 km em 4,5 min.
- Não existem usuários externos, depoimentos nem números de uso: não inventar.

## Product Principles
1. De relance: o essencial cabe numa olhada do guidão; o resto fica a um toque.
2. Simples por padrão, completo quando pedido.
3. A bike real manda: nunca fingir um dado que a bike não dá (dizer quando é estimado).
4. O bairro é o protagonista: mapa e relevo de verdade.
