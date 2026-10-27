// Service dedicato esclusivamente alla Voce Arbitrale Italiana (TTS)
// Elimina gli effetti sonori (SFX) per evitare qualsiasi conflitto, silenziamento o blocco audio su mobile/desktop.
// Esecuzione sincrona garantita per preservare i permessi di user gesture (senza setTimeout).

class PadelAudioService {
  private isVoiceMuted: boolean = false;
  private volume: number = 1.0;
  private speed: number = 0.95; // Cadenza arbitrale naturale
  private cachedItalianVoice: SpeechSynthesisVoice | null = null;
  private isAudioUnlocked: boolean = false;
  // Ignora gli eventi tardivi degli annunci sostituiti da punti piu recenti.
  private announcementSequence: number = 0;

  constructor() {
    this.initVoices();
    this.setupGlobalUnlock();
    this.startWatchdog();
  }

  // Precarica le voci di sistema
  private initVoices() {
    if (typeof window === 'undefined' || !('speechSynthesis' in window)) return;

    const findVoice = () => {
      try {
        const voices = window.speechSynthesis.getVoices();
        if (!voices || voices.length === 0) return;

        // Cerca voci con lingua italiana (it-IT, it_IT, it)
        const itVoices = voices.filter(v => {
          const l = (v.lang || '').replace('_', '-').toLowerCase();
          return l.startsWith('it');
        });

        if (itVoices.length > 0) {
          // Preferisci voce offline/locale o di sistema default
          const localVoice = itVoices.find(v => v.localService === true);
          const defaultVoice = itVoices.find(v => v.default);
          this.cachedItalianVoice = localVoice || defaultVoice || itVoices[0];
        }
      } catch {
        // Fallback silente
      }
    };

    findVoice();
    if (window.speechSynthesis.onvoiceschanged !== undefined) {
      window.speechSynthesis.onvoiceschanged = findVoice;
    }
  }

  // Sblocco immediato del motore vocale ad ogni tocco dell'utente
  public unlockAudio() {
    if (typeof window === 'undefined' || !('speechSynthesis' in window)) return;
    try {
      const synth = window.speechSynthesis;
      if (synth.paused) {
        synth.resume();
      }
      this.isAudioUnlocked = true;
    } catch {}
  }

  private setupGlobalUnlock() {
    if (typeof window === 'undefined') return;
    const unlock = () => {
      this.unlockAudio();
    };
    window.addEventListener('click', unlock, { passive: true });
    window.addEventListener('touchstart', unlock, { passive: true });
    window.addEventListener('pointerdown', unlock, { passive: true });
  }

  // Watchdog per evitare che Chrome su Android/Desktop sospenda SpeechSynthesis
  private startWatchdog() {
    if (typeof window === 'undefined' || !('speechSynthesis' in window)) return;
    setInterval(() => {
      try {
        const synth = window.speechSynthesis;
        if (synth && synth.speaking && synth.paused) {
          synth.resume();
        }
      } catch {}
    }, 3000);
  }

  public setVoiceMuted(muted: boolean) {
    this.isVoiceMuted = muted;
    if (muted && typeof window !== 'undefined' && 'speechSynthesis' in window) {
      ++this.announcementSequence;
      try {
        window.speechSynthesis.cancel();
        (window as any).__padelUtterances = [];
      } catch {}
    }
  }

  public getVoiceMuted(): boolean {
    return this.isVoiceMuted;
  }

  // Compatibilità retroattiva (SFX disattivati per policy utente)
  public setSfxMuted(_muted: boolean) {}
  public getSfxMuted(): boolean {
    return true;
  }
  public setMuted(muted: boolean) {
    this.setVoiceMuted(muted);
  }
  public getMuted(): boolean {
    return this.isVoiceMuted;
  }

  public setSpeed(speed: number) {
    this.speed = Math.max(0.7, Math.min(1.4, speed));
  }

  public setVolume(volume: number) {
    this.volume = Math.max(0, Math.min(1.0, volume));
  }

  // Effetti sonori dismessi completamente per garantire priorità assoluta alla voce arbitrale
  public playCourtBeep(_type?: string) {}
  public playApplause(_durationSec?: number) {}
  public playCheer() {}
  public playSetWinSound() {}
  public playMatchWinSound() {}
  public playSuspenseSound() {}

  // =========================================================================
  // SINTESI VOCALE ARBITRALE ITALIANA (TTS) DIRETTA E IMMEDIATA
  // Eseguita DIRETTAMENTE nel call-stack utente (senza setTimeout) per preservare i permessi
  // =========================================================================
  public speak(text: string) {
    if (this.isVoiceMuted || !text || !text.trim()) return;
    if (typeof window === 'undefined' || !('speechSynthesis' in window)) return;

    try {
      const synth = window.speechSynthesis;

      // Ripristina synth se bloccato in pausa
      if (synth.paused) {
        synth.resume();
      }

      // Ogni nuovo punteggio rende obsoleti gli annunci precedenti.
      // cancel() puo generare errori "interrupted"/"canceled": sono previsti.
      const sequence = ++this.announcementSequence;
      synth.cancel();

      const cleanText = text.trim();
      const utterance = new SpeechSynthesisUtterance(cleanText);
      utterance.lang = 'it-IT';
      utterance.rate = this.speed;
      utterance.pitch = 1.0;
      utterance.volume = this.volume;

      // Se disponibile una voce italiana valida offline, usala
      if (!this.cachedItalianVoice) {
        this.initVoices();
      }
      if (this.cachedItalianVoice) {
        utterance.voice = this.cachedItalianVoice;
      }

      // Mantieni riferimento globale per prevenire garbage collection su Chrome/V8
      const w = window as any;
      // Evita riferimenti accumulati a utterance cancellate senza evento onend.
      w.__padelUtterances = [utterance];

      const cleanup = () => {
        if (w.__padelUtterances) {
          const idx = w.__padelUtterances.indexOf(utterance);
          if (idx > -1) w.__padelUtterances.splice(idx, 1);
        }
      };

      utterance.onend = cleanup;
      utterance.onerror = (e: SpeechSynthesisErrorEvent) => {
        cleanup();

        // Il browser notifica la cancellazione anche quando e richiesta
        // intenzionalmente dal punteggio successivo o dal pulsante Muto.
        // Non e un errore e non deve rilanciare un audio ormai obsoleto.
        if (sequence !== this.announcementSequence || this.isVoiceMuted) return;
        const reason = e.error || 'unknown';
        if (reason === 'interrupted' || reason === 'canceled') return;

        console.warn('SpeechSynthesis error:', reason);

        // Riprova una sola volta senza voce forzata soltanto per problemi
        // della voce selezionata. Non ritentare per restrizioni del browser.
        if (utterance.voice && (reason === 'voice-unavailable' || reason === 'synthesis-failed')) {
          try {
            const fallback = new SpeechSynthesisUtterance(cleanText);
            fallback.lang = 'it-IT';
            fallback.rate = this.speed;
            fallback.pitch = 1.0;
            fallback.volume = this.volume;
            w.__padelUtterances = [fallback];
            const releaseFallback = () => {
              const idx = w.__padelUtterances?.indexOf(fallback) ?? -1;
              if (idx >= 0) w.__padelUtterances.splice(idx, 1);
            };
            fallback.onend = releaseFallback;
            fallback.onerror = releaseFallback;
            synth.speak(fallback);
          } catch {
            // Il punteggio continua a funzionare anche senza sintesi vocale.
          }
        }
      };

      // Riproduzione immediata
      synth.speak(utterance);

      if (synth.paused) {
        synth.resume();
      }
    } catch (e) {
      console.error('SpeechSynthesis error in speak():', e);
    }
  }
}

export const padelAudio = new PadelAudioService();
