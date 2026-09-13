# Security Policy

## Supported Versions

We actively maintain and provide security patches for the following versions of MinaFlow:

| Version | Supported          |
| ------- | ------------------ |
| 1.x.x   | :white_check_mark: |
| < 1.0   | :x:                |

---

## Reporting a Vulnerability

The MinaFlow team takes the security and privacy of user voice data and system permissions very seriously.

If you discover a security vulnerability, please **do not open a public issue**. Instead, follow responsible disclosure practices:

1. **GitHub Private Vulnerability Reporting (Preferred):**
   - Navigate to the **Security** tab of the repository on GitHub.
   - Click **Report a vulnerability** to submit an advisory privately to the maintainers.

2. **Direct Email:**
   - Email **[minaflow@krishra.com](mailto:minaflow@krishra.com)** with the subject `[Security] MinaFlow Vulnerability Report`.
   - Please include:
     - Description of the issue and potential impact
     - Clear steps to reproduce or proof-of-concept (PoC)
     - Affected version(s) and macOS version

### What You Can Expect:
- **Acknowledgment:** We will acknowledge receipt of your report within **48 hours**.
- **Assessment:** We will validate the issue, determine its severity, and keep you informed of our progress.
- **Resolution:** Once a fix is verified, a patch release and security advisory will be published, with credit given to the reporter (if desired).

---

## Core Privacy & Security Guarantees

MinaFlow is architected with strict privacy-by-design principles:
- **Zero Audio Retention:** Microphone buffers are processed strictly in-memory and are never written to unencrypted disks or stored on remote servers.
- **Local Credential Storage:** User API keys (Groq, Deepgram, OpenAI) are stored locally in the macOS Keychain and local app preferences (`~/.minatype/config.json`).
- **TLS 1.3 Encryption:** All outgoing cloud STT/LLM requests use HTTPS over TLS 1.3 directly from your Mac to your configured provider.
