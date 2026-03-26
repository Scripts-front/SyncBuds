# Phase 2: Communication - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-03-26
**Phase:** 02-communication
**Areas discussed:** CloudKit deferral, Signal format, Status live

---

## CloudKit Deferral

| Option | Description | Selected |
|--------|-------------|----------|
| Só Multipeer agora | Implementar só Multipeer. CloudKit fica pra quando tiver a conta | ✓ |
| Estrutura pronta | Criar SignalRouter com interface pro CloudKit, mas só implementar Multipeer | |
| Vou criar a conta | Criar Developer Account antes de começar Phase 2 | |

**User's choice:** Só Multipeer agora
**Notes:** User does not have Apple Developer Account. CloudKit deferred entirely.

---

## Signal Format

| Option | Description | Selected |
|--------|-------------|----------|
| Mínimo | Tipo, direção, timestamp | ✓ |
| Completo | Tipo, direção, device MAC, device name, sender platform, timestamp | |
| Você decide | Claude escolhe | |

**User's choice:** Mínimo

---

## Status Live

| Option | Description | Selected |
|--------|-------------|----------|
| Via Multipeer | Dispositivos trocam status periodicamente via Multipeer | ✓ |
| Local + notificação | Cada app detecta localmente e notifica o outro | |
| Você decide | Claude escolhe | |

**User's choice:** Via Multipeer

---

## Claude's Discretion

- MCSession configuration details
- Peer discovery and reconnection strategy
- Status update frequency
- Error handling and retry logic

## Deferred Ideas

- CloudKit integration (requires Developer Account)
- COM-02, COM-04 (CloudKit-dependent requirements)
- SignalRouter abstraction
