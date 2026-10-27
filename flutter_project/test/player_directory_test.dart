import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../lib/services/player_directory.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('salva giocatori, coppie e IDs stabili', () async {
    expect((await PlayerDirectoryStore.load())!['players'], isEmpty);
    expect(await PlayerDirectoryStore.addPlayer(' Mario   Rossi '), isNull);
    expect(await PlayerDirectoryStore.addPlayer('Luigi Verdi'), isNull);
    expect(await PlayerDirectoryStore.addPlayer('mario rossi'), isNotNull);
    final players = ((await PlayerDirectoryStore.load())!['players'] as List);
    final first = players[0]['id'] as String;
    final second = players[1]['id'] as String;
    expect(await PlayerDirectoryStore.addPair('I Fulmini', first, second), isNull);
    expect(await PlayerDirectoryStore.addPair('Duplicata', second, first), isNotNull);
    expect(await PlayerDirectoryStore.removePlayer(first), isNotNull);
    expect(await PlayerDirectoryStore.renamePlayer(first, 'Mario Nuovo'), isNull);
    final directory = (await PlayerDirectoryStore.load())!;
    expect((directory['pairs'] as List).single['playerIds'][0], first);
    expect((directory['players'] as List).first['name'], 'Mario Nuovo');
    expect(await PlayerDirectoryStore.removePair((directory['pairs'] as List).single['id'] as String), isNull);
    expect(await PlayerDirectoryStore.removePlayer(first), isNull);
  });
  test('non sovrascrive una rubrica danneggiata', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(PlayerDirectoryStore.key, '{bad');
    expect(await PlayerDirectoryStore.load(), isNull);
    expect(await PlayerDirectoryStore.addPlayer('Nuovo'), isNotNull);
    expect(prefs.getString(PlayerDirectoryStore.key), '{bad');
  });
  test('mantiene compatibilità dei dati e rifiuta riferimenti sconosciuti', () async {
    expect(PlayerDirectoryStore.decode(jsonEncode(PlayerDirectoryStore.empty())), isNotNull);
    expect(PlayerDirectoryStore.decode(jsonEncode({
      'version': 1, 'players': [], 'pairs': [{'id':'pair-1','name':'Invalida','createdAt':123,'playerIds':['a','b']}]
    })), isNull);
  });
}
