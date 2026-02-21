# Tavindo Customizations

## Objetivo
Documentar as customizacoes Tavindo para facilitar upgrades e cherry-picks.

## Regras gerais
- Nao alterar build tools (Vite, Node, pnpm, Gemfile) sem justificativa.
- Preferir overrides em `enterprise/` ou `prepend_mod_with`.
- Evitar tocar arquivos de alta rotatividade do core.
- Nunca misturar update upstream com custom Tavindo no mesmo commit.

## Estrutura de branches
- `upstream/vX.Y.Z`: espelho limpo da release oficial.
- `tavindo/base`: aponta para `upstream/vX.Y.Z`.
- `tavindo/custom`: somente commits Tavindo (sempre em cima de `tavindo/base`).
- `tavindo/dev`: integracao (base + custom).
- `tavindo/release`: pronto para deploy.

## Fluxo de update
1) Atualizar base: `upstream/vX.Y.Z` -> `tavindo/base`.
2) Reaplicar custom: `git checkout tavindo/custom` e `git rebase tavindo/base`.
3) Integracao: `tavindo/dev` -> fast-forward para `tavindo/custom`.
4) Validacao: `bundle install`, `pnpm install`, `foreman start -f Procfile.dev`.
5) Promote: `tavindo/release` -> fast-forward para `tavindo/dev`.

## Padrao de commits
Usar Conventional Commits com escopo pequeno:
- `feat(branding): add per-account logo uploads`
- `feat(widget): allow hide-powered-by`
- `refactor(overrides): move branding into module`
- `docs(custom): update customizations list`

## Customizacoes ativas

### Branding multi-conta por dominio
- Motivo: suportar marcas diferentes por conta/dominio.
- Arquivos:
  - `app/controllers/admin/branding_controller.rb`
  - `app/controllers/branding_manifest_controller.rb`
  - `app/controllers/concerns/branding_overrides.rb`
  - `lib/branding_config_resolver.rb`
  - `lib/branding_host_middleware.rb`
  - `app/views/layouts/vueapp.html.erb`
  - `app/views/widgets/show.html.erb`
- Flags/Config:
  - `LOGO`, `LOGO_DARK`, `LOGO_THUMBNAIL`
  - `HIDE_POWERED_BY` (boolean)
  - `DYNAMIC_TITLE_FROM_DOMAIN` (boolean)
- Riscos/Impacto:
  - depende de `Current.account` e `Current.branding_host`
- Teste manual:
  - Dashboard abre com favicon custom
  - Widget renderiza sem "Powered by" quando habilitado

## Customizacoes removidas/nao migradas
- Preencher conforme decisoes de upgrade.

## Pendencias
- Registrar novas customizacoes no momento do merge.
