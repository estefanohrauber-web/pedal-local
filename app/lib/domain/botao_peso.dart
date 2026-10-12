import 'power.dart';

/// O botão de peso (manual) da bike, calibrado pelas voltas que ele dá do mais leve ao mais
/// pesado. A bike não sabe a posição dele: o app guia (“gire o botão mais 2 voltas”) e conta.
class BotaoPeso {
  const BotaoPeso(this.voltas, {this.limiteMedido}) : assert(voltas >= 1);

  /// Voltas do mais leve ao mais pesado.
  final int voltas;

  /// Até que volta deu para pedalar na calibração guiada (null = não medido).
  final int? limiteMedido;

  /// Até que volta dá para pedalar. Sem a medida, 70% das voltas: as últimas de um botão
  /// magnético costumam ser pesadas demais.
  int get limite => (limiteMedido ?? (voltas * 0.7).round()).clamp(1, voltas);

  /// Subida que pede o botão no [limite].
  static const subidaMaxima = 0.10;

  /// Posição recomendada (voltas a partir do mais leve) numa subida de inclinação média
  /// [grade]; descida = mais leve.
  int posicaoPara(double grade) =>
      (grade / subidaMaxima * limite).round().clamp(0, limite);

  /// A carga equivalente (1 a 10) de uma posição, para estimar os watts.
  double cargaEquivalente(int posicao) =>
      1 + 9 * posicao.clamp(0, voltas) / voltas;

  /// Posição que dá [watts] girando a [rpm] (para os treinos guiarem pelo botão).
  int posicaoParaWatts(double watts, double rpm, PowerCalibration c) {
    if (rpm <= 0) return 0;
    final carga = (watts / rpm - c.base) / c.factor;
    return ((carga - 1) / 9 * voltas).round().clamp(0, voltas);
  }

  /// Frase para ir da posição [de] para [para]; null = já está certo.
  static String? instrucao(int de, int para) {
    final n = (para - de).abs();
    if (n == 0) return null;
    final quanto = switch (n) {
      1 => 'uma volta',
      2 => 'duas voltas',
      _ => '$n voltas',
    };
    return para > de ? 'Gire o botão mais $quanto.' : 'Volte o botão $quanto.';
  }
}
