# MinaFlow — Production Roadmap, Technical Architecture & QA Matrix

This document defines the production roadmap, integrations, core features, and test coverage requirements for **MinaFlow**.

---

## 1. Dodo Payments Integration Architecture

MinaFlow uses **Dodo Payments** as its Merchant of Record (MoR) for the **$1.99 Lifetime Deal** and software license lifecycle.

### 1.1 Purchase & Checkout Session Flow
1. **Website Checkout Initiation**:
   - Customer clicks *"Get Lifetime Deal for $1.99"* on `minaflow.com`.
   - The backend/serverless worker creates a Dodo Payments checkout session:
     ```http
     POST https://live.dodopayments.com/checkouts
     Authorization: Bearer <DODO_PAYMENTS_API_KEY>
     Content-Type: application/json

     {
       "product_id": "p_minaflow_lifetime",
       "quantity": 1,
       "return_url": "https://minaflow.com/success"
     }
     ```
   - Customer is redirected to the secure Dodo Payments checkout page.

2. **Fulfillment & License Key Generation**:
   - Once the payment succeeds, Dodo Payments:
     - Automatically generates a unique license key with an entitlement grant.
     - Automatically appends the key to the `return_url`:
       ```
       https://minaflow.com/success?payment_id=pay_123&status=succeeded&license_key=LK-XXXX-XXXX-XXXX&email=user@example.com
       ```
     - Emails the customer a purchase receipt and their license key.
     - Dispatches the webhook `entitlement_grant.delivered`.

### 1.2 Desktop App Client Activation (`/licenses/activate`)
- **Public Client Endpoint**: Does **NOT** require any server secret key, making it 100% secure for desktop binary distribution.
- **Endpoint**:
  ```http
  POST https://live.dodopayments.com/licenses/activate
  Content-Type: application/json

  {
    "license_key": "LK-XXXX-XXXX-XXXX",
    "name": "User's MacBook Pro"
  }
  ```
- **Response**:
  ```json
  {
    "id": "inst_abc123",
    "license_key_id": "lic_987",
    "status": "active",
    "activations_used": 1,
    "activations_limit": 1
  }
  ```
- **Concurrency Policy**: `activations_limit = 1` strictly enforces that only **one Mac** can run with a given key at a time. To transfer machines, the customer clicks *"Deactivate This Mac"* in Settings, which calls `POST /licenses/deactivate` and resets the seat in Dodo Payments.
- **Error Codes to Handle**:
  - `LICENSE_KEY_NOT_FOUND`: Key does not exist in the active Dodo environment.
  - `LICENSE_KEY_LIMIT_REACHED`: Key is already active on 1 Mac. Customer must deactivate on their other Mac first.
  - `INACTIVE_LICENSE_KEY`: Key has been revoked or refunded.

### 1.3 Desktop App Periodic Validation (`/licenses/validate`)
- Runs silently in the background every 24–48 hours to ensure licenses remain in good standing:
  ```http
  POST https://live.dodopayments.com/licenses/validate
  Content-Type: application/json

  {
    "license_key": "LK-XXXX-XXXX-XXXX",
    "license_key_instance_id": "inst_abc123"
  }
  ```

### 1.4 Device Deactivation (`/licenses/deactivate`)
- Triggered when a user switches Macs or unregisters their license from Settings:
  ```http
  POST https://live.dodopayments.com/licenses/deactivate
  Content-Type: application/json

  {
    "license_key": "LK-XXXX-XXXX-XXXX",
    "license_key_instance_id": "inst_abc123"
  }
  ```

---

## 2. In-App Auto-Update System (Sparkle & GitHub Releases)

To keep users on the latest version seamlessly without requiring manual re-downloads:

### Option A: Sparkle Framework (Industry Standard for macOS)
- **Why**: Used by Wispr Flow, Raycast, MacWhisper, and clean Mac software.
- **Mechanism**:
  1. MinaFlow embeds `Sparkle.framework`.
  2. `Info.plist` declares `SUFeedURL`: `https://minaflow.com/appcast.xml`.
  3. You sign releases using EdDSA (`ed25519` keypair) via Sparkle's `bin/generate_appcast`.
  4. On startup (and via a *"Check for Updates..."* menu button), Sparkle checks `appcast.xml`.
  5. If an update is detected, it displays a native modal with release notes, downloads the DMG/zip in the background, extracts it, and automatically restarts the app.

### Option B: Lightweight GitHub / Cloudflare Version Checker
- If avoiding external dependencies:
  1. App calls `https://api.github.com/repos/boltscraper/bunty/releases/latest` on launch.
  2. Compares `CFBundleShortVersionString` with the tag version.
  3. If outdated, displays an alert: *"MinaFlow v1.2.0 is available! [Download Now]"* which opens `https://minaflow.com/MinaFlow.dmg`.

---

## 3. Core Feature Specifications

| Feature | Target Behavior | Priority |
|---|---|---|
| **Push-to-Talk Mode** | Records while holding `Fn` or `⌥ Space`; stops immediately upon release. | Must Have (Done) |
| **Press-to-Toggle Mode** | Press hotkey once to start recording; press again to finish and type. | Must Have (Done) |
| **Clipboard Restoration** | Backs up user's clipboard, uses `⌘V` to paste, restores original clipboard after 1.2s. | Must Have (Done) |
| **Universal Text Injection** | Types seamlessly across Slack, Discord, Chrome, VS Code, Notes, Mail, Terminal. | Must Have (Done) |
| **Smart Multilingual** | Transcribes 100+ languages natively and executes inline translation voice prompts. | Must Have (Done) |
| **Voice Snippets** | Expands custom spoken triggers (e.g. *"my meeting link"*) into full URLs or text macros. | Must Have (Done) |
| **Audio Feedback Chimes** | Subtle soft tone when recording begins and finishes. | Must Have (Done) |
| **Settings Theme Switcher** | Crisp Light and Dark Mode matching website design tokens with zero emojis. | Must Have (Done) |
| **Input Key Routing** | Full `⌘V`, `⌘C`, `⌘A`, `⌘X`, `⌘Z` support in all Settings inputs. | Must Have (Done) |
| **Dodo License Activation** | Client-side `POST /licenses/activate` integration once checkout is live. | In Progress |
| **Sparkle Auto-Updater** | In-app background update checker and one-click update installer. | Next Sprint |

---

## 4. Quality Assurance & Testing Matrix

### 4.1 Target App Testing Matrix
Every build should be verified across these categories to prevent text injection regressions:
- [ ] **Electron Apps**: Slack, VS Code, Discord, Obsidian, Notion (verify `Cmd+V` paste succeeds and clipboard is preserved).
- [ ] **Chromium Browsers**: Google Chrome, Arc, Brave (verify text input into Google Docs, Gmail, Twitter/X).
- [ ] **WebKit Apps**: Safari, Apple Mail, Apple Notes.
- [ ] **Terminals**: macOS Terminal, iTerm2, Ghostty (verify pasting works in shell prompt without unexpected line breaks).

### 4.2 Dictation & Hotkey Scenarios
- [ ] **Short Utterance**: 1-2 words (e.g. *"Sounds good"*).
- [ ] **Paragraph Utterance**: 30-45 seconds of continuous natural speech.
- [ ] **Rapid Double Tap**: Pressing Fn twice quickly in push-to-talk mode should cancel gracefully rather than causing an audio lock.
- [ ] **Toggle Mode**: Single tap starts recording (HUD turns active); releasing key does not stop; second tap finishes and types.
- [ ] **Audio Interruption**: Headphone disconnect or microphone device switch during active recording.

### 4.3 Multilingual & Voice Command Verification
- [ ] **Direct Speech**: *"Let's schedule our quarterly sync for Friday at 2 PM."*
- [ ] **Inline Voice Translation**: *"What is your name and convert to Hindi"* $\rightarrow$ Output: *"आपका नाम क्या है?"*
- [ ] **Spoken Punctuation**: *"Dear John comma new paragraph thank you for your email period"* $\rightarrow$ Correct formatted layout.

### 4.4 License & Security Boundaries
- [ ] **Trial Boundary**: Ensure dictations count down from 50 and custom API key inputs remain locked until licensed.
- [ ] **No Key Leakage**: Verify client desktop app calls only public `/licenses/activate` and never includes admin API tokens in client binaries.
- [ ] **Settings Copy-Paste**: Verify copying API keys from browser (e.g. Groq/OpenRouter) and pressing `⌘V` into Settings textfields pastes cleanly.
