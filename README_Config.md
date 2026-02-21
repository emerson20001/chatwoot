# Tavindo - Git Workflow

Este documento padroniza o fluxo de updates e commits para reduzir conflitos.

## Estrutura de branches
- `upstream/vX.Y.Z`: espelho limpo da release oficial.
- `tavindo/base`: aponta para `upstream/vX.Y.Z`.
- `tavindo/custom`: somente commits Tavindo (sempre em cima de `tavindo/base`).
- `tavindo/dev`: integracao (base + custom).
- `tavindo/release`: pronto para deploy.

## Padrao de commits
Usar Conventional Commits com escopo pequeno:
- `feat(branding): add per-account logo uploads`
- `feat(widget): allow hide-powered-by`
- `refactor(overrides): move branding into module`
- `docs(custom): update customizations list`

## Fluxo de update (quase automatico)
1) Atualizar base:
   - trazer release nova para `upstream/vX.Y.Z`
   - fast-forward de `tavindo/base` para a release
2) Reaplicar custom:
   - `git checkout tavindo/custom`
   - `git rebase tavindo/base`
3) Integracao:
   - `tavindo/dev` -> fast-forward para `tavindo/custom`
4) Validacao:
   - `bundle install`
   - `pnpm install`
   - `foreman start -f Procfile.dev`
5) Promote:
   - `tavindo/release` -> fast-forward para `tavindo/dev`

## Dicas para reduzir conflitos
- Evitar editar arquivos de build (Gemfile, lockfiles, vite.config.ts, package.json).
- Preferir overrides em `enterprise/` e `prepend_mod_with`.
- Separar commits por feature (nao misturar update com custom).

## Merge final (quando aprovado)
```bash
git checkout tavindo/dev
git merge tavindo/merge-v4.8-into-4.10
git push origin tavindo/dev
```

## Documentacao de customizacoes
Ver `docs/customizations.md`.
