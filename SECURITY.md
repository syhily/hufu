# Security policy

## Supported versions

Hufu is an early release (0.1.x) with an implemented macOS input method, settings app, and CLI. Security fixes go into the latest release only. Reports about the current development code and its dependencies are welcome; there is no published backport policy or guaranteed response time.

## Reporting a vulnerability

Do not publish exploit details, credentials, personal configuration, typed text, or user-frequency databases in issues, PRs, or logs.

Report privately through GitHub's **Report a vulnerability** button in the repository's [Security tab](https://github.com/syhily/hufu/security/advisories/new). Private vulnerability reporting is enabled for this repository. Reports are handled by the maintainer [syhily](https://github.com/syhily) through Security Advisories; use [Issues](https://github.com/syhily/hufu/issues) only for non-sensitive hardening questions.

Privately include the affected commit/version, macOS and toolchain versions, impact, a minimal reproduction with synthetic data, and any proposed mitigation. Maintainers will triage the report and coordinate remediation and disclosure with the reporter; no fixed response SLA is promised.

## Implemented security and privacy measures

The following measures are implemented in the current MVP. They do not constitute a completed security audit; see [privacy notes](docs/privacy.md) and [architecture](docs/architecture.md) for details.

- **Local input processing, no telemetry.** Keystrokes are handled by librime inside the input-method process; the keystroke path makes no network requests. The input method does not contact the network in the background; it connects only when the user explicitly runs an AI action. librime logs default to WARNING and do not record typed text. Hufu includes no analytics, crash-reporting, or telemetry SDKs.
- **AI boundary.** `HufuAI` depends on `HufuCore`, not `RimeKit`. AI runs only when the user invokes an action (translate, polish, custom prompt) or the settings assistant. For an action, the text handed to the model is the draft in the input layer, the selection, or text just committed by Hufu; if a composition is in progress, its highlighted candidate is committed first and only that committed text is used. Typed codes, candidate lists, user-frequency databases, and statistics are never passed to AI. The default provider is Apple Foundation Models on-device; remote OpenAI-compatible providers need explicit configuration plus a separate permission to send text, and there is no silent remote fallback.
- **Credentials and configuration review.** Remote provider keys are stored in `~/Library/Application Support/Hufu/credentials.json` (directory 0700, file 0600), outside the Rime user directory so they are never synced or exported; a key saved in the login Keychain by an earlier build is moved there and the Keychain item removed. The assistant validates proposed settings and previews changes before the user applies them. Keep keys out of YAML, repository files, crash reports, screenshots, and logs.
- **Read-only migration and separate data.** Squirrel import reads `~/Library/Rime` without modifying it and skips live `*.userdb` databases. It can copy `sync/*/*.userdb.txt` snapshots into Hufu's sync directory for local frequency merging. Hufu uses `~/Library/Hufu/Rime`; advanced YAML edits are validated through a temporary `hufu deploy --dry-run` workspace and rolled back on failure.
- **Pinned engine downloads and SHA-256 verification.** The librime fetch script verifies its lock-file digests. A digest verifies integrity against the recorded value, not trust in the upstream author; review source and license changes before updates.
- **Package path protection and ownership.** Package installation filters out symlinks, unsafe relative paths, Hufu control files, user databases, and user configuration patches. It checks destination parents against the Hufu workspace and refuses to overwrite symlinks. Files overwritten outside a previous installation's ownership are backed up. Upgrade/uninstall uses recorded file hashes and preserves modified files and files shared with other packages. Dictionaries can include executable Lua; these checks do not make third-party scripts trusted.
- **Development signing.** `scripts/install-dev.sh` uses ad-hoc signing by default and verifies the signed bundle. Do not sign with a revoked certificate: macOS can classify the app as malware and move it to Trash. Override `HUFU_SIGN_IDENTITY` only with a valid identity.

The [CI workflow](.github/workflows/ci.yml) runs package tests, dictionary metadata checks, and the latency gate. Tests cover checksum rejection, package file filtering/ownership, read-only import, and AI proposal validation. The separate privacy acceptance check documented in `docs/privacy.md` must find no matches:

```bash
! grep -rlE 'composing|preedit|userdb' Packages/HufuKit/Sources/HufuAI
```

Tests and diagnostics must use synthetic input and redact secrets. Never request a user's entire RIME directory as a bug-report attachment.

## Scope

Relevant reports include unsafe configuration deployment, unintended writes to Squirrel data, malicious dictionary installation, secret leakage, AI boundary violations, input-process vulnerabilities, and dependency supply-chain failures. Ordinary reproducible bugs belong in the bug form after removing sensitive data.
