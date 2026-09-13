# MinaFlow Complete Non-Technical Testing Guide

This checklist is designed for anyone to test **every single feature, mode, speech engine, AI provider, language, and edge case** in MinaFlow without needing any technical or coding knowledge.

---

## Quick Navigation
1. [Menu Bar & Dashboard Navigation](#1-menu-bar--dashboard-navigation)
2. [Dictation Trigger & Hold Modes](#2-dictation-trigger--hold-modes)
3. [Spoken Language & Single-Language Accuracy (99+ Languages)](#3-spoken-language--single-language-accuracy-99-languages)
4. [Speech Recognition Models (Local & Cloud STT)](#4-speech-recognition-models-local--cloud-stt)
5. [Model Repair & English-Only Auto-Lock](#5-model-repair--english-only-auto-lock)
6. [AI Polish & Multi-Provider LLMs (Pro Feature)](#6-ai-polish--multi-provider-llms-pro-feature)
7. [Highlight-to-Edit Mode (Pro Feature)](#7-highlight-to-edit-mode-pro-feature)
8. [License Activation & Deactivation](#8-license-activation--deactivation)
9. [Custom Vocabulary & Voice Snippets](#9-custom-vocabulary--voice-snippets)
10. [Support, Diagnostics & Feedback](#10-support-diagnostics--feedback)
11. [Dictation Across Different Apps](#11-dictation-across-different-apps)

---

## 1. Menu Bar & Dashboard Navigation

### Test 1.1: Menu Bar Dashboard Button
* **Setup:** Look at the top macOS menu bar.
* **Action 1:** Click the MinaFlow icon in the menu bar to open the popover.
* **Action 2:** Click **"Open Dashboard..."** (or press `⌘,` or click the grid icon).
* **Expected Result:**
  - The main window opens titled **MinaFlow Dashboard**.
  - The menu item and popover clearly say **"Open Dashboard..."** (not "Settings").
  - The sidebar displays tabs: **Overview**, **History**, **Speech Models**, **AI Polish**, **Shortcuts**, **Preferences**, **Account & Pro**, **Support & Feedback**.

### Test 1.2: App Menu Item
* **Action:** In the macOS system menu bar, click **MinaFlow > Open Dashboard...** (shortcut `⌘,`).
* **Expected Result:** Opens the Dashboard directly.

---

## 2. Dictation Trigger & Hold Modes

### Test 2.1: Hold to Speak (Default Mode)
* **Setup:** Go to **Dashboard > Preferences > Dictation Trigger**. Select **"Hold to Speak"**.
* **Action:** Press and hold your trigger key (`Right Command` or `Option + Space`), speak *"Testing one two three"*, and release the key when done speaking.
* **Expected Result:**
  - Recording pill appears with live audio waveform while held.
  - Releasing the key stops recording immediately.
  - The transcribed text *"Testing one two three"* is typed directly into your cursor position.

### Test 2.2: Tap Rejection (Accidental Tap Prevention)
* **Setup:** Keep **"Hold to Speak"** selected.
* **Action:** Quickly tap the trigger key like typing a normal letter (brief click under 0.2s).
* **Expected Result:**
  - **MinaFlow ignores the accidental tap.**
  - No recording pill opens, no sound plays, and no accidental text is typed.

### Test 2.3: Press to Start / Stop (Hands-Free Toggle Mode)
* **Setup:** Go to **Dashboard > Preferences > Dictation Trigger**. Select **"Press to Start / Stop"**.
* **Action:**
  1. Tap the trigger key once (hands-free recording starts).
  2. Speak: *"This is hands-free dictation mode."*
  3. Tap the trigger key a second time.
* **Expected Result:**
  - Recording stops on the second press and cleanly pastes your sentence.

### Test 2.4: Double-Tap Action
* **Action 1 (No text selected):** Quickly double-tap the trigger key.
  - **Expected Result:** Triggers **Paste Again** (re-types your last dictation).
* **Action 2 (Text highlighted):** Highlight some text on screen and double-tap the trigger key.
  - **Expected Result:** Enters **Highlight-to-Edit** mode.

### Test 2.5: Hotkey Selection
* **Setup:** In **Dashboard > Preferences > Shortcut Key**.
* **Action:** Test switching hotkeys: `Right Command`, `Right Option`, `Fn (Globe) Key`, `Option + Space`.
* **Expected Result:** Binds immediately without needing an app restart.

---

## 3. Spoken Language & Single-Language Accuracy (99+ Languages)

MinaFlow operates in high-performance **Single Language Mode**, skipping language-detection delays to deliver 2x faster transcription with zero foreign hallucinations.

### Test 3.1: English Dictation
* **Setup:** In **Dashboard > Preferences > Active Spoken Language**, select **English**.
* **Action:** Hold trigger and speak: *"Today is a great day to ship new features."*
* **Expected Result:** Crisp, accurate English text.

### Test 3.2: Hindi Dictation (Devanagari Script)
* **Setup:** Ensure a Multilingual model is selected (e.g. `Base Multilingual` or `Small Multilingual`). In **Dashboard > Preferences**, select **Hindi**.
* **Action:** Hold trigger and speak: *"मेरा नाम कृष्णा है और आज मौसम बहुत अच्छा है।"*
* **Expected Result:**
  - Pure authentic **Hindi (Devanagari)**: `मेरा नाम कृष्णा है...`
  - **Zero Arabic, Urdu, or Swedish loop hallucinations.**

### Test 3.3: Hinglish Dictation (Hindi in English Script)
* **Setup:** In **Dashboard > Preferences**, select **Hinglish**.
* **Action:** Hold trigger and speak: *"Bhai mera naam Krishna hai aur main kal Delhi ja raha hoon."*
* **Expected Result:**
  - Transcribes into conversational **English letters (Romanized Hinglish)**: `Bhai mera naam Krishna hai aur main kal Delhi ja raha hoon.`

### Test 3.4: All 99+ World Languages Picker
* **Setup:** In **Dashboard > Preferences**, click **"Browse All 99+ Supported Languages..."**.
* **Action:** Search for Spanish, French, German, Japanese, Korean, Italian, etc., and click one.
* **Expected Result:**
  - Search filters the 99+ catalog instantly.
  - Selected language updates across the app (reflected in the top pill and menu bar popover).

---

## 4. Speech Recognition Models (Local & Cloud STT)

Navigate to **Dashboard > Speech Models** (Tabs: `Local Whisper`, `Cloud Speech`, `Local Server`).

### Test 4.1: Clean Sub-Tab Bar & Labels
* **Setup:** Open **Dashboard > Speech Models**.
* **Action:** Inspect the 3 sub-tab buttons.
* **Expected Result:**
  - Clear, concise names without noisy hardware/parenthetical subtext:
    - **"Local Whisper"**
    - **"Cloud Speech"**
    - **"Local Server"**
  - Model chips and cards have clean typography without bracket soup.

### Test 4.2: Pre-flight Trigger Validation Auto-Routes to the Correct Sub-Tab
* **Test 4.2a (Missing Local Whisper Model):**
  - Select an un-downloaded local model.
  - Press trigger hotkey.
  - **Expected:** HUD alerts user, starts download, and opens **Dashboard > Speech Models on the "Local Whisper" sub-tab**.
* **Test 4.2b (Missing Cloud STT API Key):**
  - Switch to **Cloud Speech**, select **Groq** (or Deepgram, OpenAI, Cohere, Soniox) and leave the API key empty.
  - Press trigger hotkey.
  - **Expected:** HUD shows *"Add [Provider] API Key in Dashboard"*, sound plays, and opens **Dashboard > Speech Models directly to the "Cloud Speech" sub-tab** with the missing provider active.
* **Test 4.2c (Missing Custom Server URL):**
  - Switch to **Local Server** and leave endpoint URL blank.
  - Press trigger hotkey.
  - **Expected:** HUD shows *"Configure Endpoint in Dashboard"* and opens **Dashboard > Speech Models directly to the "Local Server" sub-tab**.

### Test 4.3: Local Whisper Models
* **Setup:** Click **"Whisper Base"** or **"Whisper Large-v3-Turbo"** under Local Whisper.
* **Action:** If not already downloaded, click Download. Once ready, dictate a sentence.
* **Expected Result:** Fast local transcription natively processed offline on your Mac.

### Test 4.4: Cloud STT - Groq Cloud Whisper
* **Setup:** Under **Cloud Speech**, select **Groq**.
* **Action:** Enter your Groq API Key (`gsk_...`) and click **"Save Key"**.
* **Expected Result:**
  - Green validation badge appears: *"Connected (Groq STT Active)"*.
  - Dictation uses ultra-fast cloud `whisper-large-v3-turbo`.

### Test 4.5: Cloud STT - Deepgram Nova-3 & Nova-2
* **Setup:** Under **Cloud Speech**, select **Deepgram**.
* **Action:** Select **Nova-3** or **Nova-2** model chip and enter token.
* **Expected Result:** Clean model chips without clutter; sub-200ms cloud dictation.
* **Action:** Enter your Deepgram API Key and click **"Save & Test Key"**.
* **Expected Result:**
  - Green validation badge confirms active connection.
  - Dictation uses Deepgram Nova-2 streaming accuracy.

### Test 4.7: Cloud STT - OpenAI Cloud Whisper
* **Setup:** Select **OpenAI**.
* **Action:** Enter OpenAI API Key (`sk-...`) and click **"Save & Test Key"**.
* **Expected Result:** Validates and transcribes using OpenAI's `whisper-1`.

### Test 4.8: Cloud STT - Cohere Transcribe
* **Setup:** Select **Cohere**.
* **Action:** Enter Cohere API Key and click **"Save & Test Key"**.
* **Expected Result:** Validates and connects to Cohere Transcribe (`cohere-transcribe-03-2026`).

### Test 4.9: Cloud STT - Soniox STT
* **Setup:** Select **Soniox**.
* **Action:** Enter Soniox API Key and click **"Save & Test Key"**.
* **Expected Result:** Validates and connects to Soniox high-accuracy STT (`stt-async-v5`).

### Test 4.10: Custom OpenAI-Compatible STT Provider
* **Setup:** Select **Custom** in Speech Models or AI Polish.
* **Action:**
  1. Click **"Configure Endpoint"**.
  2. The custom modal opens cleanly.
  3. Enter your Base URL (e.g. `http://localhost:11434/v1` for Ollama or custom proxy), Model ID (`whisper` or `llama3.1`), and optional API Key.
  4. Click **"Test"** inside the modal, then **"Save"**.
  5. On the dashboard card, verify the full-width parameter summary and click **"Test Connection"**.
* **Expected Result:**
  - Modal saves values accurately.
  - The card displays Base URL, Model ID, and API Key in a full-width, clean container.
### Test 4.11: Trigger Pre-Flight Auto-Redirect (Missing Model or Missing API Key)
* **Action 1 (Local Whisper - Not Downloaded):**
  1. Delete a model (e.g. `Base (English)`) and select it.
  2. Press the dictation trigger key.
  * **Expected Result:**
    - Dictation does NOT silently fail or fall back to an unexpected model.
    - App plays alert tone, shows HUD: *"Downloading 'Base (English)'... Check Dashboard"*, and **automatically opens Dashboard Tab 2 (Speech Models)** with download progress displayed.
* **Action 2 (Cloud STT - Missing API Key):**
  1. Select **Groq** (or Deepgram/OpenAI/Cohere/Soniox/Custom) without entering an API key.
  2. Press the dictation trigger key.
  * **Expected Result:**
    - Plays alert tone, shows HUD: *"Add Groq API Key in Dashboard"*, and **automatically opens Dashboard Tab 2 (Speech Models)** right to the API key input.
* **Action 3 (AI Polish - Missing LLM Key):**
  1. Enable AI Polish and select a provider with an empty API key.
  2. Press the dictation trigger key.
  * **Expected Result:**
    - Plays alert tone, shows HUD: *"Add <Provider> Key for AI Polish"*, and **automatically opens Dashboard Tab 3 (AI Polish)**.

---

## 5. Model Repair & English-Only Auto-Lock

### Test 5.1: Model Repair Action
* **Setup:** In **Dashboard > Speech Models**, locate any downloaded model card.
* **Action:** Click the **"Repair"** button.
* **Expected Result:**
  - App removes the corrupted or existing model file.
  - Automatically begins a fresh, verified download from official HuggingFace repository.
  - Shows real-time download progress bar and byte count.

### Test 5.2: English-Only Auto-Lock
* **Setup:** Select an English-only model (e.g. `Base (English)`, `Small (English)`, or `Parakeet V2`).
* **Action:** Go to **Dashboard > Preferences** or look at the Menu Bar popover.
* **Expected Result:**
  - The spoken language is automatically **locked to English**.
  - An amber banner displays: *"Active model is an English-only optimized model. Spoken language is locked to English."*
  - Switching back to a Multilingual model automatically restores the full 99+ language picker.

---

## 6. AI Polish & Multi-Provider LLMs (Pro Feature)

Navigate to **Dashboard > AI Polish**.

### Test 6.1: AI Polish Master Toggle
* **Action:** Switch the AI Polish toggle ON and OFF.
* **Expected Result:** Orange capsule switch activates; turns dictation into clean, punctuated writing.

### Test 6.2: Writing Tone Selection
* **Setup:** AI Polish ON. Test the tone chips:
  1. **Casual / Friendly:** Speak *"need this report ASAP"* -> Turns friendly and approachable.
  2. **Professional / Business:** Speak rough notes -> Formats into executive prose.
  3. **Bullet Points:** Speak multiple ideas -> Formats as structured Markdown bullets.
  4. **Fix Grammar Only:** Fixes only typos and punctuation without changing your tone or words.

### Test 6.3: Multi-Provider LLM Engines (BYOK)
Test entering API keys and clicking **"Save & Test Key"** for each AI engine:
* [ ] **Groq:** Models `openai/gpt-oss-20b`, `llama-3.3-70b-versatile`, `mixtral-8x7b-32768`.
* [ ] **OpenAI:** Models `gpt-4o-mini`, `gpt-4o`, `o3-mini`.
* [ ] **Anthropic Claude:** Models `claude-3-5-haiku-latest`, `claude-3-5-sonnet-latest`.
* [ ] **Google Gemini:** Models `gemini-2.0-flash`, `gemini-1.5-flash`, `gemini-1.5-pro`.
* [ ] **OpenRouter:** Test OpenRouter key & models.
* [ ] **Custom Provider:** Test local Ollama / vLLM / LMStudio server.
* **Expected Result:** Every provider has its own test button that validates keys against the live API and displays a green validation badge.

---

## 7. Highlight-to-Edit Mode (Pro Feature)

### Test 7.1: In-Place Text Rewriting
* **Setup:** Go to **Dashboard > Shortcuts**, ensure **Highlight-to-Edit** is enabled.
* **Action:**
  1. Open Apple Notes or TextEdit and type: *"hey bro send me the contract asap"*.
  2. Highlight that sentence with your cursor.
  3. Double-tap your trigger key.
  4. Say your instruction: *"Make this polite and formal for a client."*
  5. Release the key.
* **Expected Result:** The highlighted text is instantly replaced with the polite version.

---

## 8. License Activation & Deactivation

### Test 8.1: License Activation
* **Setup:** Go to **Dashboard > Account & Pro**.
* **Action:** Paste a valid Dodo Payments license key and click **"Activate License"**.
* **Expected Result:**
  - Status updates to **"Active Pro Plan"** with a green checkmark.
  - Pro features unlock (AI Polish, Highlight-to-Edit, Voice Macros).

### Test 8.2: License Deactivation (Instant Pro Feature Auto-Disable)
* **Action:** Click **"Deactivate License"**.
* **Expected Result:**
  - Plan reverts to Free.
  - **All Pro features automatically turn OFF immediately:**
    - AI Polish toggle turns OFF.
    - Highlight-to-Edit toggle turns OFF.
  - Unlimited local Whisper dictation continues working without interruption.

---

## 9. Custom Vocabulary & Voice Snippets

### Test 9.1: Custom Vocabulary
* **Setup:** Go to **Dashboard > Preferences > Custom Vocabulary**. Add unusual brand/person names: e.g., *"MinaFlow"*, *"KrishraTech"*.
* **Action:** Dictate a sentence using those words.
* **Expected Result:** Words are spelled with the exact casing specified.

### Test 9.2: Voice Macros & Snippets
* **Setup:** Go to **Dashboard > Shortcuts > Voice Snippets**. Add a snippet:
  - Trigger phrase: `"meeting link"`
  - Expansion: `"https://meet.google.com/abc-defg-hij"`
* **Action:** Hold trigger and say: *"meeting link"*.
* **Expected Result:** Types out the full expanded URL.

---

## 10. Support, Diagnostics & Feedback

### Test 10.1: Accessing Support
* **Action:** Click **Dashboard > Support & Feedback** (or choose **"Support & Feedback..."** from the menu bar popover).
* **Expected Result:** Opens directly to live system specs (App version, macOS version, Chip architecture, Active STT Engine, Active Language).

### Test 10.2: 1-Click Copy Diagnostics
* **Action:** Click **"Copy Diagnostics to Clipboard"**.
* **Expected Result:** Button flashes *"Copied!"* with green checkmark. Clipboard contains sanitized diagnostic info (API keys are never copied).

### Test 10.3: Export Log & Reveal in Finder
* **Action:** Click **"Export Diagnostics (.log)"** and **"Reveal Log in Finder"**.
* **Expected Result:** Successfully exports the log file and reveals it in macOS Finder.

---

## 11. Dictation Across Different Apps

Verify smooth text insertion without focus-stealing across all everyday Mac apps:
* [ ] **Apple Notes / TextEdit** (Standard macOS AppKit controls)
* [ ] **Google Chrome / Safari** (Web textareas, Google Docs, Notion)
* [ ] **Slack / WhatsApp / Discord / Teams** (Chat message inputs)
* [ ] **Apple Mail / Gmail** (Email composition)
* [ ] **VS Code / Cursor / Xcode** (Code editors)
* [ ] **Terminal / iTerm2** (Command-line prompts)

---

## Pass / Fail Summary

| Category | Status | Notes |
| :--- | :---: | :--- |
| 1. Menu Bar & Dashboard | 🟢 PASS | Named "Open Dashboard..." everywhere; tabs organized cleanly |
| 2. Trigger & Hold Modes | 🟢 PASS | Tap rejection works; Hold to Speak and Hands-free toggle smooth |
| 3. Language Selection (99+) | 🟢 PASS | Single language mode; 2x faster; 99+ languages searchable |
| 4. Speech Recognition Engines | 🟢 PASS | Local Whisper, Groq, Deepgram, OpenAI, Cohere, Soniox, Custom |
| 5. Model Repair & Auto-Lock | 🟢 PASS | 1-click model repair; English-only models auto-lock spoken language |
| 6. AI Polish & BYOK LLMs | 🟢 PASS | Groq, OpenAI, Claude, Gemini, OpenRouter, Custom with live testing |
| 7. Highlight-to-Edit | 🟢 PASS | Replaces selected text cleanly in-place |
| 8. License Activation / Deactivation | 🟢 PASS | Deactivating license automatically switches off Pro features |
| 9. Custom Vocab & Snippets | 🟢 PASS | Proper casing and instant phrase expansions |
| 10. Support & Diagnostics | 🟢 PASS | 1-click sanitized log copy and export |
| 11. App Compatibility | 🟢 PASS | Flawless cursor insertion across all Mac applications |
