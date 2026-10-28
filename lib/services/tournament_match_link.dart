/// Collegamento immutabile tra una partita giocata e uno slot di torneo.
/// Le squadre dello slot sono salvate per impedire importazioni dopo
/// modifiche a gironi o vincitori dei turni precedenti.
class TournamentMatchLink {
  static bool _id(dynamic value) => value is String && value.isNotEmpty && value.length <= 128;

  static bool valid(dynamic value) {
    if (value is! Map || value.length != 5) return false;
    return _id(value['tournamentId']) && _id(value['fixtureId']) &&
        _id(value['homeId']) && _id(value['awayId']) &&
        value['homeId'] != value['awayId'] &&
        value['drawCreatedAt'] is int && (value['drawCreatedAt'] as int) > 0;
  }

  static Map<String, dynamic> build({required String tournamentId,
    required String fixtureId, required String homeId, required String awayId,
    required int drawCreatedAt}) => {
    'tournamentId': tournamentId,
    'fixtureId': fixtureId,
    'homeId': homeId,
    'awayId': awayId,
    'drawCreatedAt': drawCreatedAt,
  };
}
