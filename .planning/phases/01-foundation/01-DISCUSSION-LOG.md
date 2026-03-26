# Phase 1: Foundation - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-03-25
**Phase:** 01-foundation
**Areas discussed:** Entitlements setup, IOBluetooth spike, Device registry, Estrutura do projeto

---

## Entitlements Setup

| Option | Description | Selected |
|--------|-------------|----------|
| Sim, tenho conta | Posso criar App IDs, provisioning profiles, e CloudKit containers | |
| Não tenho conta | Vou precisar criar — isso afeta CloudKit | ✓ |
| Tenho mas só pessoal | Conta gratuita, sem CloudKit production | |

**User's choice:** Não tenho conta
**Notes:** User will create Apple Developer Account in parallel

| Option | Description | Selected |
|--------|-------------|----------|
| Vou criar a conta | Inscrever no Apple Developer Program | ✓ |
| Sem CloudKit por ora | Começar só com Multipeer | |

**User's choice:** Vou criar a conta

---

## IOBluetooth Spike

| Option | Description | Selected |
|--------|-------------|----------|
| Sim, tenho fone | Fone Bluetooth third-party disponível | ✓ |
| Não tenho agora | Preciso comprar ou emprestar | |
| Só tenho AirPods | AirPods mas quer testar third-party | |

**User's choice:** Sim, tenho fone

| Option | Description | Selected |
|--------|-------------|----------|
| Só connect/disconnect | Validar closeConnection() libera A2DP | |
| Também enumerar | Connect/disconnect + listar dispositivos | |
| Completo | Connect/disconnect + listar + estado em tempo real | ✓ |

**User's choice:** Completo

---

## Device Registry

| Option | Description | Selected |
|--------|-------------|----------|
| Mínimo | Nome, MAC, último visto, última plataforma | |
| Completo | Nome, MAC, tipo, ícone, último visto, preferências | |
| Você decide | Claude escolhe | ✓ |

**User's choice:** Você decide

| Option | Description | Selected |
|--------|-------------|----------|
| Automático | Fone conectado é sempre o ativo | |
| Manual | Usuário marca qual fone gerenciar | |
| Você decide | Claude escolhe | ✓ |

**User's choice:** Você decide

---

## Estrutura do Projeto

Skipped by user — deferred to Claude's discretion.

---

## Claude's Discretion

- Device registry data model fields
- Active device selection mechanism
- Project folder structure and module organization

## Deferred Ideas

None
