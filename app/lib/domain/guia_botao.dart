import 'dart:math' as math;

import 'botao_peso.dart';
import 'ride_session.dart';

/// Metros pedalados desde a última instrução do botão antes de dar outra fora dos avisos (o
/// começo do pedal conta como uma: dá para aquecer no mais leve).
const botaoIntervaloM = 150.0;

/// Metros que o relevo precisa continuar pedindo a mudança antes de o app falar (tira os
/// soluços do relevo).
const botaoConfirmaM = 30.0;

/// Mudança do botão fora dos avisos: para que volta ir e a frase que diz isso.
class MudancaBotao {
  const MudancaBotao(this.posicao, this.frase);

  final int posicao;
  final String frase;
}

/// Guia o botão de peso numa rota: acompanha o relevo e diz quando girar e quanto. Pesa um
/// pouco antes da subida (olha os 200 m à frente) e só alivia depois que ela acaba (quando os
/// últimos metros e as rampas logo adiante já aliviaram).
class GuiaBotao {
  GuiaBotao(this.botao);

  final BotaoPeso botao;

  double _ultima = 0;
  double? _pedindoDesde;
  int _sentido = 0;

  /// Sentido da última mudança (1 = pesou, −1 = aliviou). Voltar só uma volta logo depois é
  /// soluço do relevo: não vale a fala.
  int _ultimoSentido = 0;

  /// Inclinação que pede mais peso: a mais forte entre os 200 m à frente e os 100 m em volta.
  double _perto(Terrain t, double d) =>
      math.max(t.lookahead(d, alertLookaheadM), t.lookahead(math.max(0.0, d - 50), 100));

  /// Inclinação que ainda segura o peso: além da [_perto], os últimos 40 m (até o topo, você
  /// ainda está subindo) e a rampa de 200 m mais forte que começa nos próximos 200 m.
  double _longe(Terrain t, double d) {
    final atras = math.max(0.0, d - 40);
    var g = math.max(_perto(t, d), t.lookahead(atras, d - atras));
    for (var k = 20.0; k <= alertLookaheadM + 1e-9; k += 20) {
      g = math.max(g, t.lookahead(d + k, alertLookaheadM));
    }
    return g;
  }

  /// No aviso de subida ou descida, em [d] com o botão em [posicao]: a posição nova, ou null se
  /// o botão já está no lugar. Na subida, pesa para a rampa que o aviso fala (a mais forte); na
  /// descida, só alivia se o topo já passou.
  int? noAviso(Terrain t, double d, int posicao, RideAlert alerta) {
    final int alvo;
    if (alerta.kind == AlertKind.subida) {
      alvo = math.max(botao.posicaoNoRelevo(alerta.grade), botao.posicaoNoRelevo(_perto(t, d)));
      if (alvo <= posicao) return null;
    } else {
      alvo = botao.posicaoNoRelevo(_longe(t, d));
      if (alvo >= posicao) return null;
    }
    _ultima = d;
    _pedindoDesde = null;
    _ultimoSentido = alvo > posicao ? 1 : -1;
    return alvo;
  }

  /// A cada passo, fora dos avisos: a mudança do botão quando for hora, ou null.
  /// [avisoChegando]: um aviso de subida ou descida sai logo (ele cuida do botão).
  MudancaBotao? passo(Terrain t, double d, int posicao, {bool avisoChegando = false}) {
    final perto = _perto(t, d);
    final sobe = botao.posicaoNoRelevo(perto);
    final int alvo;
    final double g;
    if (sobe > posicao) {
      alvo = sobe;
      g = perto;
    } else {
      final longe = _longe(t, d);
      final desce = botao.posicaoNoRelevo(longe);
      if (desce >= posicao) {
        _pedindoDesde = null;
        return null;
      }
      alvo = desce;
      g = longe;
    }
    final sentido = alvo > posicao ? 1 : -1;
    if ((alvo - posicao).abs() == 1 && sentido == -_ultimoSentido) {
      _pedindoDesde = null;
      return null;
    }
    if (_pedindoDesde == null || sentido != _sentido) {
      _pedindoDesde = d;
      _sentido = sentido;
    }
    if (avisoChegando || d - _pedindoDesde! < botaoConfirmaM || d - _ultima < botaoIntervaloM) return null;
    _ultima = d;
    _pedindoDesde = null;
    _ultimoSentido = sentido;
    return MudancaBotao(alvo, _frase(posicao, alvo, g));
  }

  /// “Subida de 3 por cento: gire o botão mais uma volta.”
  String _frase(int de, int para, double g) {
    final acao = BotaoPeso.instrucao(de, para)!;
    final plano = botao.plano;
    final String onde;
    if (para > de) {
      onde = para > plano ? 'Subida de ${(g * 100).round()} por cento' : 'Trecho plano';
    } else {
      // Aliviando, o número da subida confundiria: pode haver outra logo adiante segurando o peso.
      onde = para > plano
          ? 'Trecho mais leve'
          : g <= -BotaoPeso.descidaLeve
          ? 'Descida'
          : 'Trecho plano';
    }
    return '$onde: ${acao[0].toLowerCase()}${acao.substring(1)}';
  }
}
