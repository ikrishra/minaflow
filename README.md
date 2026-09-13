<div align="center">
  <img src="Resources/AppLogo.png" alt="MinaFlow app icon" width="128" height="128">

  # MinaFlow: The Open-Source Wispr Flow & Superwhisper Alternative for macOS

  **Fast, private push-to-talk AI voice dictation with local Whisper & BYOK cloud intelligence. Zero subscriptions.**

  Speak naturally in any Mac app. MinaFlow captures your voice, polishes away pauses and rambling, and types clean, punctuated text directly at your cursor.

  [![Open-Source Alternative to Wispr Flow](https://img.shields.io/badge/Alternative%20To-Wispr%20Flow-FF5500.svg)](https://minaflow.krishra.com)
  [![Alternative to Superwhisper](https://img.shields.io/badge/Alternative%20To-Superwhisper-blue.svg)](https://minaflow.krishra.com)
  [![Local Offline Whisper](https://img.shields.io/badge/Inference-100%25%20Offline%20Whisper-success.svg)](https://minaflow.krishra.com)
  [![macOS 13+](https://img.shields.io/badge/macOS-13%2B%20(Apple%20Silicon%20%26%20Intel)-111827)](https://minaflow.krishra.com)
  [![License: MIT](https://img.shields.io/badge/license-MIT-gray.svg)](LICENSE)

  [Website](https://minaflow.krishra.com) · [Download](https://minaflow.krishra.com/download) · [Roadmap](ROADMAP.md) · [Testing Checklist](TESTING_CHECKLIST.md) · [Documentation](https://minaflow.krishra.com/docs)
</div>

---

## Overview

MinaFlow is a native macOS menu bar app built in Swift and SwiftUI, engineered as an ultra-fast, privacy-first, **open-source alternative to subscription dictation tools like Wispr Flow, Superwhisper, and Aqua Voice**.

It runs seamlessly across every app on your Mac. Hold or toggle your hotkey (`Option + Space` or `Right Command`), speak your thoughts naturally with filler words, pauses, and revisions, and MinaFlow transcribes, shapes, and injects clean text directly into your active text field (VS Code, Cursor, Slack, Notion, Chrome, Terminal, etc.).

---

## Why an Open-Source Alternative to Wispr Flow & Superwhisper?

Most modern voice dictation apps for Mac trap your productivity behind $12–$15/month subscriptions ($144+/year), store private voice audio on remote cloud servers, or only support recent Apple Silicon Macs.

**MinaFlow changes that entirely:**

| Feature | MinaFlow (Open Source) | Wispr Flow | Superwhisper | Apple Dictation |
| :--- | :---: | :---: | :---: | :---: |
| **Pricing** | **Free (100% Open Source)** / $1.99 Pro | $144/year ($12–$15/mo) | $8/month ($96/yr) | Free (Basic) |
| **Source Code** | **100% Open Source on GitHub** | Closed Proprietary | Closed Proprietary | Closed Proprietary |
| **Audio Privacy** | **Zero retention (in-memory only)** | Stored on cloud servers | Mixed cloud/local | Apple servers |
| **Offline Local Models** | **6 Whisper models bundled free** | No (requires internet) | Paid tiers only | Basic Siri |
| **BYOK (Bring Your Own Key)** | **Free Groq, Deepgram, Ollama** | No (locked to their servers) | Partial | No |
| **Highlight-to-Edit** | **Included** | Yes ($144/yr) | Yes ($96/yr) | No |
| **Context-Aware Tone** | **Automatic app detection** | Yes | Partial | No |
| **Architecture** | **Native Swift / Metal Universal** | Electron / Wrapper | Native | Native |
| **Supported Hardware** | **Apple Silicon (M1–M4) & Intel** | Apple Silicon only | Apple Silicon only | Universal |

---

### Why MinaFlow?
- **Zero Configuration to Start:** Bundled with offline local Whisper models. Works completely offline with zero API keys and zero internet connection required.
- **Real-Time Cloud LPUs (BYOK):** Connect your own keys for Groq (`whisper-large-v3-turbo`), Deepgram Nova-3, OpenAI, Claude, Gemini, or local Ollama servers.
- **Context-Aware Tone Shaping:** Automatically detects the foreground app and shapes text to match (e.g. raw shell commands in Terminal, code syntax in Cursor, executive prose in Mail).
- **Highlight-to-Edit:** Select text on screen, speak instructions, and watch it rewrite in place.
- **Complete Voice Privacy:** Zero telemetry, zero cloud audio storage, and local-first execution.

---

## How It Works

```
 ┌────────────────┐     ┌──────────────────────┐     ┌───────────────────────┐     ┌────────────────────┐
 │  Press Hotkey  │ ──► │ Stream Audio Buffer  │ ──► │  Transcribe & Polish  │ ──► │  Direct Insertion  │
 │ (Option+Space) │     │ (CoreAudio <1ms mute)│     │(Local Metal / Groq LPU│     │ (Accessibility API)│
 └────────────────┘     └──────────────────────┘     └───────────────────────┘     └────────────────────┘
```

1. **Trigger:** Press or hold your customizable global shortcut. A floating glass pill HUD appears with a live 6-bar responsive audio waveform.
2. **Acoustic Protection:** Built-in hardware speakers are muted in under 1ms to eliminate feedback loops (smartly bypassed when wearing AirPods or headphones).
3. **Transcription:** Audio is transcribed in-memory via bundled local Whisper or ultra-low-latency cloud LPUs.
4. **Context Injection:** MinaFlow inspects the active app and tab URL, applies tone adjustments, and types the result at your cursor while preserving your system clipboard.

---

## Key Features

### 1. 100% Offline Local Whisper Models
Bundled with `whisper.cpp` and optimized with Apple Silicon Metal acceleration. Transcribe on-device with zero internet connection:
- **Parakeet V2 (Recommended English):** Ultra-fast acoustic model delivering ~9x real-time speed.
- **Whisper Large-v3-Turbo (Recommended Multilingual):** High accuracy across 99+ languages, Indic scripts, and accented speech.
- **Whisper Small & Base:** Lightweight models for minimal battery and memory footprint.
- **Dedicated Hinglish Models:** Optimized phonetic recognition for bilingual workflows (`apex-q8`).

### 2. Context-Aware Tone & Format Shaping
MinaFlow dynamically recognizes the app holding your cursor and adjusts output formatting:
- **Terminal & Shells (iTerm, Warp, Terminal, Kitty):** Outputs valid commands without conversational chatter or markdown backticks.
- **Code Editors (Cursor, VS Code, Xcode, Zed):** Preserves programming conventions, camelCase variables, and code syntax.
- **Work Chat (Slack, Microsoft Teams):** Concise, structured workplace communication.
- **Personal Chat (WhatsApp, Telegram, Messages):** Natural cadence, friendly tone, and emojis.
- **Email (Mail.app, Superhuman, Outlook):** Professional greetings, paragraphs, and executive prose.
- **Notes & Docs (Notion, Obsidian, Bear, Apple Notes):** Formatted lists, headings, and bullet points.

### 3. Active Browser Tab Context
Detects active tab URLs across Safari, Google Chrome, Arc, Brave, Microsoft Edge, Opera, Orion, and Comet. Gives AI models immediate context on what you are reading or researching.

### 4. Highlight-to-Edit Voice Revision
Select any sentence or paragraph on screen, hold your edit hotkey, and speak revision instructions (*"Make this punchier"*, *"Translate to German"*, or *"Fix grammar"*). MinaFlow surgically replaces the highlighted selection in place.

### 5. Acoustic Echo Cancellation & Hardware Speaker Muting
When recording with built-in MacBook microphones, MinaFlow mutes hardware speaker output at the CoreAudio level in <1ms to prevent audio feedback from music or video. When using AirPods or Bluetooth headphones, speaker muting is automatically bypassed.

### 6. Voice Snippets & Spoken Shortcuts
Define trigger phrases in settings that instantly expand into frequently used text, meeting links, email templates, or URLs.

### 7. Custom Vocabulary & Technical Dictionary
Add custom industry terms, framework names, acronyms, or colleague names to your dictionary so Whisper transcribes them with 100% accuracy.

---

## Privacy & Data Flow Matrix

| Mode | What Leaves Your Machine | Where Data Goes | Audio Retention |
| :--- | :--- | :--- | :--- |
| **Local Whisper** | **Nothing.** Audio is processed 100% in-memory on device. | Stays on Mac | Zero retention. Fully offline. |
| **Cloud Speech (BYOK)** | Audio stream sent over direct encrypted HTTPS. | Directly to your configured provider (Groq / Deepgram) | Zero retention. Processed and discarded. |
| **AI Polish (BYOK)** | Transcribed text only. No audio is ever sent to LLMs. | OpenAI, Anthropic, Gemini, Groq, or local Ollama | Subject to your provider's API terms. |

All API keys are stored securely in your macOS Keychain and local preferences (`~/.minatype/config.json`). No telemetry or audio is collected by MinaFlow.

---

## Architecture

| Layer | Implementation | Purpose |
| :--- | :--- | :--- |
| **App Shell & UI** | SwiftUI, AppKit, NSPanel | Menu bar controller, dashboard window, onboarding flow |
| **Floating HUD** | CoreGraphics, SwiftUI | Responsive 6-bar audio waveform pill and notch display |
| **Audio Pipeline** | AVFoundation, CoreAudio | Ring buffer mic streaming, hardware mute controller |
| **Local Engine** | `whisper.cpp`, Metal | Local on-device GGUF Whisper execution |
| **Cloud Engine** | URLSession (REST & WebSocket) | Direct BYOK streaming clients for Groq and Deepgram |
| **Context Service** | `NSWorkspace`, AppleScript, AXUI | Frontmost app detection, browser tab URL extraction |
| **Insertion Engine** | macOS Accessibility (`AXUIElement`) | Cursor detection, clipboard restoration, keystroke simulation |

---

## Installation

### Pre-built Application
Download the signed `.dmg` installer from [minaflow.krishra.com/download](https://minaflow.krishra.com/download) or from [GitHub Releases](https://github.com/ikrishra/minaflow/releases).

1. Open `MinaFlow.dmg` and drag `MinaFlow.app` into your Applications folder.
2. Launch MinaFlow.
3. Grant **Microphone** and **Accessibility** permissions when prompted.

---

## Build from Source

### Prerequisites
- macOS 13.0 (Ventura) or later
- Apple Silicon or Intel Mac
- Xcode 15+ or Xcode Command Line Tools (`xcode-select --install`)
- Swift 5.9+

### Build & Run
```bash
# 1. Clone repository
git clone https://github.com/ikrishra/minaflow.git
cd minaflow

# 2. Compile and launch native app
make run
```

### Makefile Commands
```bash
make build   # Compile native MinaFlow.app bundle
make run     # Build and launch MinaFlow in background
make kill    # Stop any running MinaFlow instances
make dmg     # Build distributable macOS DMG installer
make clean   # Remove build artifacts and caches
```

---

## Configuration

Configure options directly in **Menu Bar > Dashboard**, or edit `~/.minatype/config.json`:

```json
{
  "sttProvider": "localWhisper",
  "localWhisperModel": "parakeet-v2",
  "hotkey": "option+space",
  "mode": "pushToTalk",
  "toneMode": "auto",
  "isBrowserURLExtractionEnabled": true,
  "customVocabulary": [
    "MinaFlow",
    "Kubernetes",
    "PostgreSQL",
    "Next.js"
  ]
}
```

---

## Contributing

Contributions are welcome! Please follow these steps:

1. Fork the repository on GitHub.
2. Create your feature branch: `git checkout -b feature/my-feature`.
3. Verify your changes against the [Testing Checklist](TESTING_CHECKLIST.md).
4. Commit your changes: `git commit -m "feat: add my feature"`.
5. Push to your branch and submit a Pull Request.

Check the [Roadmap](ROADMAP.md) for planned integrations and open issues.

---

## License

MinaFlow is open-source software licensed under the [MIT License](LICENSE).
