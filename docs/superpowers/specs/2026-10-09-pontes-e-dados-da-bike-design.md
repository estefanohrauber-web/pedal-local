# Pontes no relevo e dados da bike real — correção

Data: 2026-10-09. Relato do primeiro pedal com a Winnek (rota “Entre pontes”): a bike
conectava, mas giro e potência ficavam em zero; caiu algumas vezes; na ponte a inclinação
era −18 % e o pedal chegava a 50 km/h sem pedalar.

## O que os dados mostraram

- **Relevo:** a altitude vem do terreno (Valhalla `/height`). Embaixo de uma ponte está o
  rio: na Ponte Emílio Baumgart (253 m) o perfil descia de 541 m para 504 m e subia de novo
  (−35 % / +18 %). A Ponte Jorge Lacerda (185 m) tinha o mesmo vale, menor. As ladeiras de
  verdade do bairro chegam a 22 % (“Casa trabalho”), então limitar a inclinação estragaria
  rotas certas.
- **Bike:** os 4 pedais da noite de 08/10 têm giro e potência zero em todas as amostras, mas
  a frequência cardíaca chegava como 0 a cada segundo: os pacotes chegavam, só sem a
  cadência no último pacote de cada leitura. O padrão FTMS deixa a bike dividir uma leitura
  em vários pacotes (bit 0, “More Data”); o app trocava a leitura inteira a cada pacote, e o
  pacote só com velocidade e FC apagava a cadência e a potência do anterior. Hipótese forte,
  ainda sem os bytes crus da Winnek para confirmar.
- **Quedas:** sem registro do motivo (o logcat já tinha girado).

## Correções

- **Pontes e túneis em reta:** ao criar a rota, o app pergunta ao Valhalla
  (`/trace_attributes`, `map_snap`) quais trechos são ponte ou túnel (marcação do
  OpenStreetMap). Cada ponta é projetada na rota, procurando perto da distância esperada
  (vale para ida e volta pela mesma ponte). A altitude de cada trecho vira uma reta entre as
  cabeceiras, 10 m para fora; pontes a menos de 40 m uma da outra viram uma reta só. Depois
  vem a suavização de sempre. Se esse pedido falhar, a rota sai com o relevo do terreno.
- **Rotas salvas:** coluna `routes.relief` (banco versão 6): 0 = plana, 1 = terreno,
  2 = pontes em reta. Ao abrir o app, as rotas abaixo de 2 têm o relevo refeito (mesmos
  pontos; nome, cor e o que a pessoa mudou nesse meio-tempo ficam). Sem internet, fica para
  a próxima abertura. No celular: “Entre pontes” passou de 81/80 m de subida/descida para
  50/50 m e a ponte de −35 % para −5,5 %; “Casa trabalho” quase não mudou.
- **Leitura em pedaços:** `IndoorBikeAssembler` junta os campos dos pacotes; um campo que
  parou de vir há mais de 3 s some (para não ficar um giro antigo).
- **Diário da bike:** `files/bike_log.txt` (até 4000 linhas, continua entre aberturas) com
  conexão, serviços e características, controle aceito, quedas com o código do Android e
  cada pacote cru em hexadecimal. A tela “Dados da bike” mostra os últimos pacotes e tem
  “Copiar o diário” (as 400 linhas mais novas), também sem bike conectada. Pelo cabo:
  `adb exec-out run-as com.pedallocal.app cat files/bike_log.txt`.

## Fica para depois

- Confirmar com o diário de um pedal de verdade se a Winnek divide os pacotes e por que
  cai (no teste de hoje, sem a bike ligada: erro 133 do Android, o normal com ela
  desligada ou longe).
- Se o giro chegar como 0 mesmo pedalando, testar o comando “iniciar” do FTMS antes do
  pedal (algumas bikes FitShow só mandam dados depois dele).
- O pedal começa a andar sozinho numa descida antes da primeira pedalada (física certa,
  como no Zwift). Dá para segurar até o primeiro giro, se incomodar.

## Verificação

290 testes automáticos. Instalado no celular: relevo das 2 rotas refeito sozinho ao abrir;
tela “Dados da bike” com o diário; diário gravando a tentativa de reconexão.
