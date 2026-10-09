import 'route_builder.dart';
import 'routes_store.dart';

/// Rotas salvas com relevo antigo (antes das pontes em reta, ou planas porque a altitude
/// falhou): refaz o relevo de cada uma. Devolve quantas foram refeitas; as que não deram
/// (sem internet) ficam para a próxima vez que o app abrir.
Future<int> upgradeRelief(RoutesStore store, RouteBuilder builder) async {
  var feitas = 0;
  for (final rota in await store.all()) {
    if (rota.relief >= reliefVersion) continue;
    final nova = await builder.refreshRelief(rota);
    if (nova == null) continue;
    // A pessoa pode ter renomeado ou apagado a rota enquanto o serviço respondia.
    final atual = await store.byId(rota.id);
    if (atual == null) continue;
    await store.upsert(
      atual.copyWith(
        points: nova.points,
        gainM: nova.gainM,
        lossM: nova.lossM,
        relief: nova.relief,
      ),
    );
    feitas++;
  }
  return feitas;
}
