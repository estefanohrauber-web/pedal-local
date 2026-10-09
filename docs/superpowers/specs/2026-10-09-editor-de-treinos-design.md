# Editor de treinos — design

Data: 2026-10-09. Pedido: “criar a função do usuário montar os próprios treinos, veja o que
os concorrentes fazem e faça melhor”. Escolhas do usuário: montar com **blocos prontos**
(e não arrastando no gráfico nem escrevendo uma frase) e, como extra desta versão,
**ajustar o treino durante o pedal**. O esboço das telas foi aprovado como está.

## O que os concorrentes fazem (resumo da pesquisa)

- **Zwift e MyWhoosh:** blocos arrastados num gráfico (potência em % do FTP, rampas, pedal
  livre, giro e mensagens na tela). Só se monta no computador (Zwift, na tela inicial do
  jogo) ou no site (MyWhoosh); o celular só toca o treino.
- **TrainerRoad:** editor só para computador, sem atualização há anos.
- **TrainingPeaks:** monta no site; pelo celular quase não dá.
- **Wahoo SYSTM:** não tem editor; importa arquivos de outros apps.
- **intervals.icu:** o treino é escrito em texto (“5x 1m 110%”); rápido para quem conhece.
- **TrainerDay:** “séries e repetições” montam os tiros de uma vez; durante o pedal dá para
  pular, esticar o trecho e mudar a intensidade. O editor é no site.
- **Rouvy:** o editor mais elogiado; guarda blocos para reaproveitar.

**Onde o Pedalaqui faz melhor:** monta inteiro no celular, com blocos prontos e uma série
num bloco só; intensidade em palavras com os watts do FTP; a frase do bloco é **falada**;
subida simulada dentro do treino; funciona em qualquer bike (com controle, a bike segura a
meta; sem controle, a voz orienta); e ajustes durante o pedal em todos os treinos.

## Onde fica

- Aba **Treinos**: a seção **“Meus treinos”** entra logo depois do cartão do FTP, com o
  botão **“Criar treino”** e os treinos do usuário (cartão igual ao da biblioteca: nome,
  duração, nível e o desenho). Sem treinos, mostra só o convite e o botão.
- Tela de um treino da biblioteca: botão **“Copiar e editar”** (menos no Teste de rampa,
  que tem regras próprias). Vira um treino do usuário chamado “<nome> (cópia)”, já em
  blocos (veja “Copiar um treino pronto”).
- Tela de um treino do usuário: **Editar**, **Duplicar** e **Apagar** (pede confirmação).
- Os treinos do usuário não entram nos planos nesta versão.

## A tela de montar

- Topo: o **nome** (campo de texto; vazio vira “Meu treino”), o **desenho** do treino nas
  cores das zonas (o mesmo `WorkoutChart`) e a linha “36 min · Difícil · carga 48”. Tudo
  se atualiza a cada mudança.
- Lista dos blocos, cada um num cartão com o nome do bloco, o tempo e um resumo em palavras
  com os watts (“1 min muito forte (231 W) + 1 min leve”). Tocar abre os ajustes; segurar
  e arrastar muda a ordem; o menu do cartão tem **Duplicar** e **Apagar**.
- **“+ Adicionar bloco”** abre a lista dos 7 tipos; o bloco novo entra antes do último
  “Soltar” (ou no fim, se não houver).
- Treino novo já começa com **Aquecer (10 min)** e **Soltar (5 min)**.
- **Salvar** no alto. Sair com mudanças não salvas pergunta “Descartar as mudanças?”.

## Os 7 blocos

| Bloco | Valores ao criar | O que se ajusta |
|---|---|---|
| Aquecer | 10 min, de 45 % a 65 % | tempo, começa em, termina em, giro, frase |
| Ritmo constante | 10 min, 70 % | tempo, intensidade, giro, frase |
| Série de tiros | 4 × (1 min a 110 % + 1 min a 50 %) | repetições; tiro: tempo, intensidade, giro; descanso: tempo, intensidade; frase |
| Rampa | 5 min, de 60 % a 90 % | tempo, começa em, termina em, giro, frase |
| Subida simulada | 5 min, 85 %, 6 %, giro 70–85 | tempo, inclinação, intensidade, giro, frase |
| Pedal livre | 5 min, sem meta | tempo, frase |
| Soltar | 5 min, de 55 % a 40 % | tempo, começa em, termina em, giro, frase |

- **Tempo:** botões − e + (passo de 15 s até 2 min, 30 s até 10 min, 1 min acima);
  segurar o botão repete e acelera.
- **Intensidade em palavras:** Muito leve (50 %), Leve (65 %), Moderado (82 %), Forte
  (97 %), Muito forte (112 %), Quase tudo (130 %) e Tudo (160 %) — uma palavra por zona,
  as mesmas de hoje. O botão da zona em que a % está fica marcado, na cor da zona. Um
  ajuste fino (− e +, de 1 %) mostra “110 % · 231 W”. O treino guarda a %, e os watts saem
  do FTP de agora (se o FTP muda, os treinos acompanham).
- **Giro:** Livre, Pesado 70–80, Normal 85–95, Rápido 95–105, ou “Outro” (mínimo e máximo).
- **Inclinação** (subida): de 1 % a 15 %, passo de 1 %.
- **Frase da voz:** opcional; vazia, a voz fala o padrão de hoje (“1 minuto muito forte,
  231 watts, giro de 90 a 100.”). Com frase, ela vem antes do padrão, como os “cues” da
  biblioteca.
- **Série de tiros:** a voz conta os tiros (“Tiro 3 de 4.”) antes da frase.
- **Pedal livre:** sem meta de potência e sem aviso de “fora da meta”; numa bike com
  controle, a carga volta para o botão da bike durante o bloco. No desenho, uma barra
  cinza clara a meia altura; no nível e na carga do treino, conta como Muito leve (50 %).

## Durante o pedal (todos os treinos, menos o Teste de rampa)

Quatro botões na tela do treino: **Pular bloco**, **+1 min**, **Mais leve −5 %** e
**Mais forte +5 %**.

- **Pular bloco:** vai para o começo do próximo trecho (numa série, o próximo tiro ou
  descanso). No último trecho, encerra o treino como concluído.
- **+1 min:** o trecho atual fica 1 minuto mais longo (até +30 min por trecho).
- **Mais leve / mais forte:** muda todas as metas daqui para a frente em 5 % (de −30 % a
  +30 %), por cima do ajuste do plano. Fica só neste pedal; o treino salvo não muda.
  Some num Pedal livre.
- A voz confirma: “Pulando para o próximo bloco.”, “Mais 1 minuto.”, “Mais leve: 220
  watts.”. Com a bike no modo ERG, a meta nova vai para a bike na hora.

## Copiar um treino pronto

Os trechos viram blocos assim: o primeiro trecho que sobe com “Aquecendo” vira Aquecer; o
último que desce vira Soltar; pares de trechos repetidos seguidos (2 ou mais vezes) viram
uma Série de tiros; trecho com inclinação vira Subida; rampa vira Rampa; o resto, Ritmo
constante. As frases (cues) vão junto. O desenho da cópia fica igual ao do original.

## Dados

- Tabela nova `custom_workouts` (id, nome, blocos em JSON, criado e alterado em), e coluna
  `workout_name` nos pedais: o histórico mostra o nome mesmo se o treino for apagado ou
  renomeado. Banco vai para a versão 7, sem mexer no que já existe.
- Id dos treinos do usuário: `meu-` + um código único. O `workoutLookupProvider` procura
  na biblioteca e depois nos treinos do usuário, então a tela do treino, o pedal e o resumo
  funcionam igual para os dois.
- Na hora de pedalar, os blocos viram os trechos de sempre (`WorkoutStep`); a série vira
  os pares repetidos, cada tiro com a frase “Tiro 3 de 4” (antes da frase do usuário). O
  `WorkoutStep` ganha `free` (pedal livre). O condutor do treino (`WorkoutRunner`) ganha
  pular, +1 min e o ajuste de ±5 %.

## Limites e casos especiais

- Nome até 40 letras. De 1 a 50 blocos; treino de até 4 h; bloco de 15 s a 2 h; série de
  2 a 30 repetições; intensidade de 30 % a 200 %; giro de 50 a 130.
- Salvar sem blocos não deixa (mensagem “Coloque pelo menos um bloco.”).
- Sem FTP testado, os watts saem do FTP estimado pelo peso, como na biblioteca.
- Apagar o treino não apaga os pedais feitos com ele.

## Fora (fica para depois)

Importar treinos do Zwift (.zwo), escrever o treino numa frase, treinos do usuário nos
planos, compartilhar por link (depende dos servidores) e meta por frequência cardíaca.

## Testes

- Domínio: blocos → trechos (cada tipo, série, livre), números (tempo, nível, carga),
  JSON de ida e volta, cópia de cada treino da biblioteca com o mesmo desenho, limites.
- Condutor: pular (no meio, no último), +1 min, ±5 % (com limites e no ERG), pedal livre
  sem meta e sem toque de “fora da meta”, contagem dos tiros na voz.
- Banco: migração da versão 6 para a 7 mantendo pedais e rotas; salvar, listar e apagar.
- Telas: criar um treino do zero e salvar; editar um bloco; reordenar; copiar da
  biblioteca; apagar com confirmação; sair sem salvar; os quatro botões no pedal.
