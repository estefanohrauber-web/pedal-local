# Plano 5 — Treinos — design

Data: 2026-10-08. Pedido: “começar a parte de treinos: estudar o que os concorrentes
fazem e criar todas as opções que estão ‘em breve’ com as melhores opções que existem
hoje”. Os “em breve” da aba Treinos eram: sessões rápidas (3), teste de calibração e
plano iniciante; na escolha de pedal, “Treino” e “Contra o fantasma” (este já existia
desde o plano 4 e só faltava liberar).

## O que os concorrentes fazem (resumo da pesquisa)

- **Zwift, TrainerRoad, Rouvy, Wahoo SYSTM:** treinos estruturados com metas em
  porcentagem do FTP; **modo ERG** (a bike segura a potência e você só mantém o giro);
  **teste de rampa** (a meta sobe a cada minuto; FTP = 75 % do melhor minuto) ou teste de
  20 min (95 % da média); **planos** de várias semanas (Zwift: 2 a 4 treinos por semana).
- **TrainerRoad:** pergunta “como foi?” no fim e ajusta os próximos treinos (Adaptive
  Training).
- **Peloton:** zonas de potência 1 a 7 com cores; o Bike+ ajusta a resistência sozinho
  (Auto-Follow, que é o ERG deles).
- **Wahoo SYSTM:** treino por esforço percebido (RPE 1–10) para quem não tem potência.

## Decisões

- **Zonas:** as 7 de Coggan (as mesmas de Peloton/Zwift), cada uma com uma palavra de
  esforço (“Muito leve” … “Tudo”) e uma cor. A tela mostra a palavra grande e os watts
  menores: dá para treinar pela sensação.
- **FTP:** do teste de rampa, ou digitado em Ajustes; sem nenhum, 2 W/kg do peso.
- **Teste de rampa** (substitui o “teste de calibração”): 5 min de aquecimento, depois
  +6 % do FTP por minuto a partir de 50 %. Acaba no botão “Não aguento mais” ou sozinho
  (15 s abaixo de 70 % da meta, ou 10 s com o giro abaixo de 40). FTP = 75 % do melhor
  minuto; é guardado no fim e aparece no resumo. Com potência estimada, a conta é a
  mesma (o que importa é ser consistente).
- **Biblioteca (11 treinos):** Primeiro giro, Cadência alta, Recuperação, Resistência 30
  e 40 min, Sweet spot 2 × 10, Intervalos 5 × 1 min, Pirâmide 1-2-3-2-1, Tabata 8 × 20 s,
  Sprints 6 × 15 s, Subida longa simulada (com inclinação de verdade na física: a
  velocidade cai) e o Teste de rampa. Cada um com duração, dificuldade (pela intensidade
  média) e “carga” (TSS).
- **Durante o treino:** meta grande na cor da zona, tempo do trecho, giro alvo, se está
  na meta (folga de 6 % ou 8 W, 8 s para se ajustar), o próximo trecho e o desenho do
  treino. Voz: cada trecho (“Forte! 1 minuto muito forte, 158 watts, giro de 85 a 100”),
  aviso 5 s antes de trecho forte, um toque por trecho quando fica 15 s fora da meta,
  “metade do bloco”, resultado do teste. Com potência estimada, mostra a carga que dá a
  meta a 85 rpm. O treino termina sozinho e vai para o resumo.
- **Modo ERG / controle da bike (FTMS):** ao conectar, o app lê o que a bike aceita
  (0x2ACC: potência, resistência, simulação) e, nos treinos, manda a meta de potência
  pelo Control Point (0x2AD9: pedir controle, iniciar, meta; no fim, reset). Sem potência
  mas com simulação: manda a inclinação dos trechos de subida. Liga/desliga nos Ajustes
  e na tela do treino. A bike simulada aceita ERG, para testar sem a bike.
  **Não testado numa bike real:** a Winnek pode não aceitar comandos; a tela “Dados da
  bike” agora mostra “Controle de carga pelo app: aceita … / não aceita”.
- **Planos:** Começando (4 semanas), Mais fôlego (6 semanas, com semana leve e teste no
  começo e no fim) e Rei das subidas (4 semanas). 3 treinos por semana, nos dias que a
  pessoa puder; qualquer ordem dentro do plano conta. Progresso: treinos feitos até o
  fim depois do início do plano.
- **Adaptação:** “Como foi o treino?” no resumo (Fácil +3 %, Na medida +1 %, Difícil 0,
  Muito difícil −3 %, Não consegui terminar −5 %), entre 85 % e 115 %. Vale para todos os
  treinos menos o teste. Zera em Ajustes.

## Dados

- Banco versão 5: `rides.workout_id`, `rides.feeling` (1–5), `rides.ftp` (do teste).
  No treino, `laps = 1` quando foi até o fim (ou quando o teste deu FTP).
- Ajustes: `ftp`, `planoId`, `planoInicio`, `intensidade`, `controleBike`.

## Fora (continua para depois)

Criar treino próprio (editor), treino numa rota (metas sobre o mapa), simulação de subida
nas rotas (a bike endurecer nas ladeiras do bairro — usa o mesmo controle FTMS), cinta
cardíaca e zonas de FC, Strava, comunidade (servidor).

## Verificação

263 testes automáticos (domínio, dados, motor do pedal e telas). Não instalado no
celular nesta etapa: o aparelho estava desconectado do computador.
