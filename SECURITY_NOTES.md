# ArcAttestationLog — Security Notes

**Non-goal:** this is NOT a full trust / identity / reputation system. Approvals are not sybil-resistant.

---
### Core Invariants (what must always hold)

### Posting invariants
- `topic != 0x0` and `contentHash != 0x0` for every stored attestation