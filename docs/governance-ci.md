# Governance CI — từ AGENTS.md thành checkpoint máy kiểm tra

## Mapping rule → check

| Rule (AGENTS.md) | Checkpoint | Script |
|---|---|---|
| Noctalia `sync_color_scheme` off limits | config không được `= true` | `governance-check.sh` |
| Noctalia builtin/community templates off limits | config không được `= true` | `governance-check.sh` |
| `gnome-keyring` off limits | không nằm trong config tracked | `governance-check.sh` |
| Plasma files byte-identical (repo side) | không track file của Plasma (`kdeglobals`, `mimeapps.list`, ...) | `governance-check.sh` |
| Không secret trong source | quét pattern key/private key | `governance-check.sh` |
| Gate commands phải exit 0 | `bash tests/run-all.sh` trong CI | `.github/workflows/governance.yml` |

## Judgment-only / không check máy được

- **Plasma byte-identity lúc cài** (`check-plasma-intact.sh snapshot/compare`):
  cần máy thật của user, plasmashell phải stopped — không chạy được trên
  GitHub Actions. Giữ làm gate thủ công theo runbook, không đưa vào CI.
- **"Hand every sudo line to the user"**: hành vi của agent, không phải
  trạng thái repo — giữ trong AGENTS.md, do reviewer bot kiểm tra.
- **Stow from main checkout**: ngữ cảnh máy local, không có trong repo.

## Cách chạy

```bash
bash scripts/governance-check.sh          # local
bash scripts/test-governance-check.sh     # tự test script (RED→GREEN)
bash tests/run-all.sh                     # gate command của AGENTS.md
git config core.hooksPath .githooks       # bật pre-commit local
```
