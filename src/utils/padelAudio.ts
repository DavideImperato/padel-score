// Service dedicato esclusivamente alla Voce Arbitrale Italiana (TTS)
// Elimina gli effetti sonori (SFX) per evitare qualsiasi conflitto, silenziamento o blocco audio su mobile/desktop.
// Esecuzione sincrona garantita per preservare i permessi di user gesture (senza setTimeout).

class PadelAudioService {
  private isVoiceMuted: boolean = false;
  private volume: number = 1.0;
  private speed: number = 0.95; // Cadenza arbitrale naturale
  private cachedItalianVoice: SpeechSynthesisVoice | null = null;
  private isAudioUnlocked: boolean = false;

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
      try {
        window.speechSynthesis.cancel();
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

      // Interrompi annunci precedenti
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
      w.__padelUtterances = w.__padelUtterances || [];
      w.__padelUtterances.push(utterance);

      const cleanup = () => {
        if (w.__padelUtterances) {
          const idx = w.__padelUtterances.indexOf(utterance);
          if (idx > -1) w.__padelUtterances.splice(idx, 1);
        }
      };

      utterance.onend = cleanup;
      utterance.onerror = (e) => {
        cleanup();
        console.warn('SpeechSynthesis error:', e);
        // Se la voce specifica genera errore, riprova senza forzare la voce
        if (utterance.voice) {
          try {
            const fallback = new SpeechSynthesisUtterance(cleanText);
            fallback.lang = 'it-IT';
            fallback.rate = this.speed;
            fallback.volume = this.volume;
            synth.speak(fallback);
          } catch {}
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
