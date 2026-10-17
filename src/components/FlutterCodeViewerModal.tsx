import React, { useState } from 'react';
import { X, Copy, Check, Download, FileCode, FolderTree, Archive, Sparkles } from 'lucide-react';
import { FLUTTER_CODE_FILES, FlutterFileItem } from '../utils/flutterCodeFiles';
import JSZip from 'jszip';

interface FlutterCodeViewerModalProps {
  isOpen: boolean;
  onClose: () => void;
}

export const FlutterCodeViewerModal: React.FC<FlutterCodeViewerModalProps> = ({
  isOpen,
  onClose,
}) => {
  const [selectedFileIndex, setSelectedFileIndex] = useState(0);
  const [copied, setCopied] = useState(false);
  const [isZipping, setIsZipping] = useState(false);

  if (!isOpen) return null;

  const currentFile: FlutterFileItem = FLUTTER_CODE_FILES[selectedFileIndex] || FLUTTER_CODE_FILES[0];

  const handleCopy = () => {
    navigator.clipboard.writeText(currentFile.content);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  const handleDownloadSingle = () => {
    const blob = new Blob([currentFile.content], { type: 'text/plain;charset=utf-8' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = currentFile.filename;
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    URL.revokeObjectURL(url);
  };

  const handleDownloadAllZip = async () => {
    try {
      setIsZipping(true);
      const zip = new JSZip();

      // Add each file to the zip maintaining the relative paths
      FLUTTER_CODE_FILES.forEach((file) => {
        zip.file(file.path, file.content);
      });

      // Also add README.md
      zip.file(
        'README.md',
        `# Padel ScoreBot (Flutter)
Applicazione di tabellone segnapunti per Padel 100% offline stile ScoreBot.

## Avvio
1. Assicurati di avere Flutter installato
2. Esegui:
   \`flutter pub get\`
   \`flutter run\`
`
      );

      const zipBlob = await zip.generateAsync({ type: 'blob' });
      const url = URL.createObjectURL(zipBlob);
      const link = document.createElement('a');
      link.href = url;
      link.download = 'padel_scorebot_flutter_project.zip';
      document.body.appendChild(link);
      link.click();
      document.body.removeChild(link);
      URL.revokeObjectURL(url);
    } catch (e) {
      console.error('Error creating zip:', e);
    } finally {
      setIsZipping(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-3 sm:p-6 bg-black/85 backdrop-blur-md">
      <div className="w-full max-w-5xl h-[88vh] bg-slate-900 border border-slate-700 rounded-2xl shadow-2xl overflow-hidden flex flex-col">
        {/* Modal Top Bar */}
        <div className="flex items-center justify-between px-6 py-3.5 border-b border-slate-800 bg-slate-950">
          <div className="flex items-center gap-3">
            <div className="p-2 rounded-lg bg-sky-500/10 border border-sky-500/30 text-sky-400">
              <FolderTree className="w-5 h-5" />
            </div>
            <div>
              <h3 className="text-base font-black tracking-wide text-white flex items-center gap-2">
                Codice Sorgente Flutter / Dart Completo
                <span className="px-2 py-0.5 rounded text-[10px] bg-emerald-500/20 text-emerald-400 border border-emerald-500/40">
                  Pronto per flutter run
                </span>
              </h3>
              <p className="text-xs text-slate-400">
                Tutti i file modulari richiesti + AndroidManifest & Info.plist con Landscape forzato e Wakelock.
              </p>
            </div>
          </div>

          <div className="flex items-center gap-2">
            <button
              onClick={handleDownloadAllZip}
              disabled={isZipping}
              className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-gradient-to-r from-emerald-600 to-teal-600 hover:from-emerald-500 hover:to-teal-500 text-white font-bold text-xs shadow-md shadow-emerald-950/50 transition-all border border-emerald-400/40 cursor-pointer active:scale-95"
            >
              <Archive className="w-4 h-4" />
              <span>{isZipping ? 'Creazione ZIP...' : 'Scarica Tutto (.ZIP)'}</span>
            </button>

            <button
              onClick={onClose}
              className="p-1.5 rounded-lg text-slate-400 hover:text-white hover:bg-slate-800 transition-colors cursor-pointer"
            >
              <X className="w-5 h-5" />
            </button>
          </div>
        </div>

        {/* Content: Sidebar file list + Code Viewer */}
        <div className="flex-1 flex flex-col md:flex-row overflow-hidden">
          {/* Left: Files Tabs */}
          <div className="w-full md:w-72 bg-slate-950/70 border-b md:border-b-0 md:border-r border-slate-800 p-2 overflow-y-auto shrink-0 flex md:flex-col gap-1">
            <div className="hidden md:flex items-center justify-between px-3 py-2 text-[11px] font-black uppercase tracking-wider text-slate-400">
              <span>File del Progetto:</span>
              <span className="text-sky-400 font-mono text-[10px]">{FLUTTER_CODE_FILES.length} file</span>
            </div>
            {FLUTTER_CODE_FILES.map((file, idx) => {
              const isSelected = idx === selectedFileIndex;
              return (
                <button
                  key={file.path}
                  onClick={() => setSelectedFileIndex(idx)}
                  className={`flex items-center gap-2.5 px-3 py-2 rounded-xl text-left text-xs font-semibold transition-all shrink-0 md:w-full cursor-pointer ${
                    isSelected
                      ? 'bg-sky-500/20 text-sky-300 border border-sky-500/40 font-bold shadow-sm'
                      : 'text-slate-400 hover:text-slate-200 hover:bg-slate-900 border border-transparent'
                  }`}
                >
                  <FileCode className={`w-4 h-4 shrink-0 ${isSelected ? 'text-sky-400' : 'text-slate-500'}`} />
                  <div className="truncate">
                    <div className="truncate font-mono">{file.filename}</div>
                    <div className="hidden md:block text-[10px] text-slate-500 truncate font-sans">
                      {file.path}
                    </div>
                  </div>
                </button>
              );
            })}
          </div>

          {/* Right: Code display & action bar */}
          <div className="flex-1 flex flex-col bg-slate-950 overflow-hidden">
            {/* File info bar */}
            <div className="flex items-center justify-between px-4 py-2.5 bg-slate-900/90 border-b border-slate-800 text-xs">
              <div className="flex items-center gap-2 truncate">
                <span className="font-mono text-sky-400 font-bold">{currentFile.path}</span>
                <span className="text-slate-500 hidden sm:inline">— {currentFile.description}</span>
              </div>

              <div className="flex items-center gap-2 shrink-0">
                <button
                  onClick={handleCopy}
                  className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-200 font-bold text-xs border border-slate-700 transition-colors cursor-pointer"
                >
                  {copied ? <Check className="w-3.5 h-3.5 text-emerald-400" /> : <Copy className="w-3.5 h-3.5" />}
                  <span>{copied ? 'Copiato!' : 'Copia'}</span>
                </button>

                <button
                  onClick={handleDownloadSingle}
                  className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-sky-600 hover:bg-sky-500 text-white font-bold text-xs shadow-md shadow-sky-900/30 transition-colors cursor-pointer"
                >
                  <Download className="w-3.5 h-3.5" />
                  <span>Scarica File</span>
                </button>
              </div>
            </div>

            {/* Code Body */}
            <div className="flex-1 p-4 overflow-auto font-mono text-xs sm:text-sm text-slate-300 leading-relaxed bg-[#060A12] selection:bg-sky-500/30">
              <pre className="whitespace-pre">
                <code>{currentFile.content}</code>
              </pre>
            </div>
          </div>
        </div>

        {/* Footer */}
        <div className="px-6 py-3 border-t border-slate-800 bg-slate-950 flex items-center justify-between text-xs text-slate-400">
          <div className="flex items-center gap-2">
            <Sparkles className="w-4 h-4 text-[#CCFF00]" />
            <span>Tutti i file sono salvati anche sul disco locale in <code className="text-sky-300 font-mono">/flutter_project/</code></span>
          </div>
          <button
            onClick={onClose}
            className="px-5 py-1.5 rounded-lg bg-slate-800 hover:bg-slate-700 text-white font-bold transition-colors cursor-pointer"
          >
            Chiudi
          </button>
        </div>
      </div>
    </div>
  );
};
