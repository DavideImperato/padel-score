// Regression test della sintesi vocale quando i punti arrivano rapidamente.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const Module = require('node:module');
let ts;
try { ts = require('@typescript/typescript6'); } catch { ts = require('typescript'); }
Module._extensions['.ts'] = (module, filename) => {
  module._compile(ts.transpileModule(fs.readFileSync(filename, 'utf8'), {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 }, fileName: filename,
  }).outputText, filename);
};

const warnings = [];
const originalWarn = console.warn;
const originalSetInterval = global.setInterval;
console.warn = (...args) => warnings.push(args);
global.setInterval = () => 0;

const sounds = [];
const pendingErrors = [];
const voice = { lang: 'it-IT', localService: true, default: true };
const synth = {
  speaking: false,
  paused: false,
  current: null,
  onvoiceschanged: null,
  getVoices: () => [voice],
  resume() { this.paused = false; },
  cancel() {
    if (this.current) {
      const old = this.current;
      pendingErrors.push(() => old.onerror?.({ error: 'interrupted', isTrusted: true }));
      this.current = null;
    }
  },
  speak(utterance) { this.current = utterance; sounds.push(utterance); },
};
class FakeUtterance {
  constructor(text) { this.text = text; this.voice = null; this.onend = null; this.onerror = null; }
}
global.SpeechSynthesisUtterance = FakeUtterance;
global.window = { speechSynthesis: synth, addEventListener() {} };
let checks = 0;
const check = (result, label) => { assert.ok(result, label); checks++; };
try {
  const { padelAudio } = require('../src/utils/padelAudio.ts');
  for (let i = 0; i < 20; i++) padelAudio.speak(`Punto ${i}`);
  pendingErrors.splice(0).forEach(callback => callback());
  check(sounds.length === 20, '20 punteggi producono 20 richieste vocali, senza fallback aggiuntivi');
  check(synth.current?.text === 'Punto 19', 'resta valido soltanto l ultimo annuncio');
  check(warnings.length === 0, 'nessun warning per interruzioni normali');
  check(window.__padelUtterances.length === 1, 'nessun accumulo di annunci cancellati');
  padelAudio.setVoiceMuted(true);
  pendingErrors.splice(0).forEach(callback => callback());
  check(warnings.length === 0, 'muto non genera warning');
  padelAudio.speak('Non va pronunciato');
  check(sounds.length === 20, 'muto blocca nuovi annunci');
  padelAudio.setVoiceMuted(false);
  padelAudio.speak('Voce assente');
  const failedVoice = synth.current;
  failedVoice.onerror({ error: 'voice-unavailable', isTrusted: true });
  check(sounds.length === 22 && sounds[21].voice === null, 'fallback una volta con voce browser');
  check(warnings.length === 1 && warnings[0][1] === 'voice-unavailable', 'errore reale loggato con codice');
  padelAudio.speak('Punteggio nuovo');
  pendingErrors.splice(0).forEach(callback => callback());
  check(sounds.at(-1).text === 'Punteggio nuovo', 'fallback interrotto non scavalca punto successivo');
  const noPermission = synth.current;
  noPermission.onerror({ error: 'not-allowed', isTrusted: true });
  check(sounds.at(-1) === noPermission, 'nessun fallback su permessi negati');
  check(warnings.at(-1)[1] === 'not-allowed', 'log utile sui problemi veri');
  padelAudio.speak('Annuncio precedente');
  const staleVoice = synth.current;
  padelAudio.speak('Annuncio aggiornato');
  const beforeStale = sounds.length;
  staleVoice.onerror({ error: 'voice-unavailable', isTrusted: true });
  check(sounds.length === beforeStale && synth.current.text === 'Annuncio aggiornato', 'errore tardivo non riproduce audio vecchio');
  const beforeCancelWarn = warnings.length;
  synth.current.onerror({ error: 'canceled', isTrusted: true });
  check(warnings.length === beforeCancelWarn, 'cancellazione normale non produce warning');
  console.warn = originalWarn;
  console.log(`OK ${checks} verifiche sintesi vocale React`);
} finally {
  console.warn = originalWarn;
  global.setInterval = originalSetInterval;
  delete global.window;
  delete global.SpeechSynthesisUtterance;
}
