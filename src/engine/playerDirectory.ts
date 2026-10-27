/** Anagrafica offline indipendente dai checkpoint e dallo storico partita. */
export const PLAYER_DIRECTORY_KEY = 'padel_player_directory_v1';
export const MAX_PLAYERS = 150;
export const MAX_PAIRS = 150;
export interface RegisteredPlayer { id: string; name: string; createdAt: number; }
export interface RegisteredPair { id: string; name: string; playerIds: [string, string]; createdAt: number; }
export interface PlayerDirectory { version: 1; players: RegisteredPlayer[]; pairs: RegisteredPair[]; }
export interface PlayerStorage { getItem(key: string): string | null; setItem(key: string, value: string): void; }
export type DirectoryResult = { ok: true; directory: PlayerDirectory } | { ok: false; reason: string };
const blank = (): PlayerDirectory => ({ version: 1, players: [], pairs: [] });
const str = (v: unknown, limit: number): v is string => typeof v === 'string' && v.trim().length > 0 && v.length <= limit;
const integer = (v: unknown) => Number.isSafeInteger(v) && (v as number) > 0;
const canonical = (name: string) => name.trim().replace(/\s+/g, ' ').toLocaleLowerCase('it-IT');
const isRecord = (v: unknown): v is Record<string, any> => !!v && typeof v === 'object' && !Array.isArray(v);
export function isPlayerDirectory(v: unknown): v is PlayerDirectory {
  if (!isRecord(v) || v.version !== 1 || !Array.isArray(v.players) || !Array.isArray(v.pairs) || v.players.length > MAX_PLAYERS || v.pairs.length > MAX_PAIRS) return false;
  const players = v.players as unknown[];
  const pairs = v.pairs as unknown[];
  if (!players.every(p => isRecord(p) && str(p.id, 100) && str(p.name, 60) && integer(p.createdAt))) return false;
  const ids = new Set((players as RegisteredPlayer[]).map(p => p.id));
  if (ids.size !== players.length || new Set((players as RegisteredPlayer[]).map(p => canonical(p.name))).size !== players.length) return false;
  if (!pairs.every(p => isRecord(p) && str(p.id, 100) && str(p.name, 60) && integer(p.createdAt) && Array.isArray(p.playerIds) && p.playerIds.length === 2 && p.playerIds[0] !== p.playerIds[1] && p.playerIds.every((id: unknown) => typeof id === 'string' && ids.has(id)))) return false;
  const pids = (pairs as RegisteredPair[]).map(p => p.id);
  const compositions = (pairs as RegisteredPair[]).map(p => [...p.playerIds].sort().join('|'));
  return new Set(pids).size === pids.length && new Set(compositions).size === compositions.length;
}
export function readPlayerDirectory(storage: PlayerStorage): PlayerDirectory | null {
  try { const raw = storage.getItem(PLAYER_DIRECTORY_KEY); if (raw === null) return blank(); const v: unknown = JSON.parse(raw); return isPlayerDirectory(v) ? v : null; }
  catch { return null; }
}
const id = () => typeof crypto !== 'undefined' && 'randomUUID' in crypto ? crypto.randomUUID() : `${Date.now()}-${Math.random().toString(36).slice(2)}`;
function update(storage: PlayerStorage, apply: (d: PlayerDirectory) => string | null): DirectoryResult {
  const directory = readPlayerDirectory(storage);
  if (!directory) return { ok: false, reason: 'Archivio non leggibile: nessuna modifica effettuata.' };
  const err = apply(directory);
  if (err) return { ok: false, reason: err };
  if (!isPlayerDirectory(directory)) return { ok: false, reason: 'Dati non validi.' };
  try { storage.setItem(PLAYER_DIRECTORY_KEY, JSON.stringify(directory)); return { ok: true, directory }; }
  catch { return { ok: false, reason: 'Impossibile salvare sul dispositivo.' }; }
}
export function addPlayer(storage: PlayerStorage, name: string): DirectoryResult {
  return update(storage, d => {
    const clean = name.trim().replace(/\s+/g, ' ');
    if (!str(clean, 60)) return 'Inserisci un nome (massimo 60 caratteri).';
    if (d.players.length >= MAX_PLAYERS) return 'Limite giocatori raggiunto.';
    if (d.players.some(p => canonical(p.name) === canonical(clean))) return 'Giocatore già presente.';
    d.players.push({ id: id(), name: clean, createdAt: Date.now() }); return null;
  });
}
export function renamePlayer(storage: PlayerStorage, playerId: string, name: string): DirectoryResult {
  return update(storage, d => {
    const p = d.players.find(x => x.id === playerId); if (!p) return 'Giocatore non trovato.';
    const clean = name.trim().replace(/\s+/g, ' ');
    if (!str(clean, 60)) return 'Nome non valido.';
    if (d.players.some(x => x.id !== playerId && canonical(x.name) === canonical(clean))) return 'Nome già presente.';
    p.name = clean; return null;
  });
}
export function removePlayer(storage: PlayerStorage, playerId: string): DirectoryResult {
  return update(storage, d => {
    if (!d.players.some(p => p.id === playerId)) return 'Giocatore non trovato.';
    if (d.pairs.some(p => p.playerIds.includes(playerId))) return 'Rimuovi prima le coppie che includono questo giocatore.';
    d.players = d.players.filter(p => p.id !== playerId); return null;
  });
}
export function addPair(storage: PlayerStorage, name: string, firstId: string, secondId: string): DirectoryResult {
  return update(storage, d => {
    const clean = name.trim().replace(/\s+/g, ' ');
    if (!str(clean, 60)) return 'Inserisci il nome della coppia.';
    if (d.pairs.length >= MAX_PAIRS) return 'Limite coppie raggiunto.';
    if (firstId === secondId || !d.players.some(p => p.id === firstId) || !d.players.some(p => p.id === secondId)) return 'Seleziona due giocatori diversi.';
    if (d.pairs.some(p => p.playerIds.includes(firstId) && p.playerIds.includes(secondId))) return 'Coppia già presente.';
    d.pairs.push({ id: id(), name: clean, playerIds: [firstId, secondId], createdAt: Date.now() }); return null;
  });
}
export function removePair(storage: PlayerStorage, pairId: string): DirectoryResult {
  return update(storage, d => { if (!d.pairs.some(p => p.id === pairId)) return 'Coppia non trovata.'; d.pairs = d.pairs.filter(p => p.id !== pairId); return null; });
}
