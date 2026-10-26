import { Team, PadelMatchSnapshot, MatchSettings } from '../types/padel';
import {
  processPoint,
  createInitialSnapshot,
  getRotationOrder,
  getTeamForPlayerId,
  PlayerId,
  ScoringEvent,
  ScoringResult,
} from './padelScoringEngine';

export interface MatchStoreState {
  snapshot: PadelMatchSnapshot;
  history: PadelMatchSnapshot[];
}

export type ScoreEventListener = (event: ScoringEvent, nextSnapshot: PadelMatchSnapshot) => void;
export type UndoListener = () => void;
export type ResetListener = (firstServerPlayerId: PlayerId) => void;
export type ServerChangeListener = (nextServerPlayerId: PlayerId) => void;

export class PadelMatchStore {
  private state: MatchStoreState;
  private settings: MatchSettings;
  private blocked: boolean = false;
  private listeners: Set<() => void> = new Set();

  public onScoreEvent?: ScoreEventListener;
  public onUndo?: UndoListener;
  public onReset?: ResetListener;
  public onServerChange?: ServerChangeListener;

  constructor(initialSettings: MatchSettings, initialSnapshot?: PadelMatchSnapshot) {
    this.settings = { ...initialSettings };
    const firstServerId = this.normalizePlayerId(this.settings.firstServerPlayerId);
    this.state = {
      snapshot: initialSnapshot ? { ...initialSnapshot } : createInitialSnapshot(firstServerId),
      history: [],
    };
  }

  private normalizePlayerId(id: number): PlayerId {
    if (id === 1 || id === 2 || id === 3 || id === 4) return id;
    return 1;
  }

  public getState = (): MatchStoreState => {
    return this.state;
  };

  public getSnapshot = (): PadelMatchSnapshot => {
    return this.state.snapshot;
  };

  public getHistory = (): PadelMatchSnapshot[] => {
    return this.state.history;
  };

  public getSettings = (): MatchSettings => {
    return this.settings;
  };

  public updateSettings(partial: Partial<MatchSettings>): void {
    this.settings = { ...this.settings, ...partial };
  }

  public setBlocked(blocked: boolean): void {
    this.blocked = blocked;
  }

  public isBlocked(): boolean {
    return this.blocked;
  }

  public subscribe = (listener: () => void): (() => void) => {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  };

  private notify(): void {
    for (const listener of this.listeners) {
      listener();
    }
  }

  /**
   * Elabora in modo atomico e transazionale un nuovo punto.
   * Garantisce che chiamate sequenziali rapide non perdano punti
   * prima che React o l'interfaccia eseguano un nuovo render.
   */
  public addPoint(team: Team): ScoringResult | null {
    if (this.blocked) return null;
    if (this.state.snapshot.matchWinner) return null;

    const currentSnapshot = this.state.snapshot;
    const result = processPoint(currentSnapshot, team, this.settings);
    if (!result) return null;

    const { nextSnapshot, event } = result;
    this.state = {
      snapshot: nextSnapshot,
      history: [...this.state.history, currentSnapshot],
    };

    this.notify();
    this.onScoreEvent?.(event, nextSnapshot);
    return result;
  }

  /**
   * Esegue l'Undo atomico ripristinando lo snapshot precedente.
   */
  public undo(): PadelMatchSnapshot | null {
    if (this.blocked) return null;
    if (this.state.history.length === 0) return null;

    const prevSnapshot = this.state.history[this.state.history.length - 1];
    this.state = {
      snapshot: prevSnapshot,
      history: this.state.history.slice(0, -1),
    };

    this.notify();
    this.onUndo?.();
    return prevSnapshot;
  }

  /**
   * Avanza manualmente il battitore nel set corrente salvando lo snapshot in cronologia.
   */
  public toggleServingTeam(): PlayerId {
    const current = this.state.snapshot;
    const nextRot = current.servingRotationIndex + 1;
    const firstServerId = this.normalizePlayerId(this.settings.firstServerPlayerId);
    const rotation = getRotationOrder(firstServerId);
    const nextPlayerId = rotation[nextRot % rotation.length];
    const nextTeam = getTeamForPlayerId(nextPlayerId);

    this.state = {
      history: [...this.state.history, current],
      snapshot: {
        ...current,
        servingTeam: nextTeam,
        servingRotationIndex: nextRot,
      },
    };

    this.notify();
    this.onServerChange?.(nextPlayerId);
    return nextPlayerId;
  }

  /**
   * Esegue il reset del match rispettando rigorosamente settings.firstServerPlayerId.
   */
  public resetMatch(customSettings?: MatchSettings): PlayerId {
    if (customSettings) {
      this.settings = { ...customSettings };
    }
    const firstServerId = this.normalizePlayerId(this.settings.firstServerPlayerId);
    const initialSnap = createInitialSnapshot(firstServerId);

    this.state = {
      snapshot: initialSnap,
      history: [],
    };

    this.notify();
    this.onReset?.(firstServerId);
    return firstServerId;
  }

  /**
   * Avvia una nuova partita con nuove impostazioni o impostazioni correnti,
   * azzerando cronologia e inizializzando il servizio su firstServerPlayerId.
   */
  public startNewMatch(newSettings: MatchSettings): PlayerId {
    this.settings = { ...newSettings };
    const firstServerId = this.normalizePlayerId(this.settings.firstServerPlayerId);
    const initialSnap = createInitialSnapshot(firstServerId);

    this.state = {
      snapshot: initialSnap,
      history: [],
    };

    this.notify();
    return firstServerId;
  }
}
