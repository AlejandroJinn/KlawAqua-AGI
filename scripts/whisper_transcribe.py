#!/usr/bin/env python3
"""
KlawAqua Voice — Whisper speech-to-text
Convierte audio a texto usando Whisper local (base model, ~150MB)
"""
import whisper
import sys, os, json, time

MODEL = None

def load_model(name="base"):
    """Carga modelo Whisper (base=150MB, small=500MB, medium=1.5GB)"""
    global MODEL
    if MODEL is None:
        print(f"🎤 Cargando Whisper {name}...")
        MODEL = whisper.load_model(name)
    return MODEL

def transcribe(audio_path, model_name="base", language="es"):
    """Transcribe audio a texto"""
    model = load_model(model_name)
    start = time.time()
    result = model.transcribe(audio_path, language=language, fp16=False)
    elapsed = time.time() - start
    return {
        "text": result["text"].strip(),
        "segments": len(result.get("segments", [])),
        "language": result.get("language", language),
        "time_s": round(elapsed, 1)
    }

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Uso: whisper_transcribe.py <audio.mp3> [modelo: base|small]")
        sys.exit(1)
    
    audio = sys.argv[1]
    model = sys.argv[2] if len(sys.argv) > 2 else "base"
    
    if not os.path.exists(audio):
        print(f"❌ Archivo no encontrado: {audio}")
        sys.exit(1)
    
    result = transcribe(audio, model)
    print(json.dumps(result, ensure_ascii=False, indent=2))
