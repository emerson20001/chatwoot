# Chatwoot - Guia Local (Docker + Hot Reload)

Este guia foi criado para esta versão customizada do projeto.

## 1) Pré-requisitos

- Docker + Docker Compose
- Git
- `make`
- `rbenv` (para comandos Ruby locais como `bundle`, `rails`, `rspec`)

## 2) Instalar e configurar `rbenv`

`rbenv` gerencia a versão do Ruby da sua máquina.  
Ele **não** deve ir para o Git (já está no `.gitignore`).

### Ubuntu/Debian (exemplo)

```bash
sudo apt update
sudo apt install -y rbenv ruby-build
```

Adicione no `~/.bashrc`:

```bash
eval "$(rbenv init -)"
```

Recarregue o shell:

```bash
source ~/.bashrc
```

Instale a versão do projeto:

```bash
rbenv install $(cat .ruby-version)
rbenv local $(cat .ruby-version)
gem install bundler
bundle install
```

## 3) Subir ambiente Docker (sem rebuild)

Usar sempre estes atalhos:

```bash
make docker_up
make docker_ps
```

Isso sobe o ambiente com:
- `docker compose up -d --no-build --remove-orphans`
- banco em volume externo `chatwoot_postgres_data` (persistente)
- rede externa compartilhada `shared_local_net`

### Persistência do banco (importante)

- O Postgres usa volume Docker externo: `chatwoot_postgres_data`.
- `docker compose down` **não apaga** esse volume.
- Limpar `node_modules`, `.pnpm-store` ou rodar `pnpm install` **não afeta** o banco.
- Só perde banco se remover volume manualmente (`docker volume rm/prune --volumes`).

### Rede compartilhada com outros projetos (ex: WordPress)

- O Chatwoot está configurado para usar a rede Docker externa `shared_local_net`.
- Se outro projeto (WordPress) usar a mesma rede, os containers se comunicam por nome.
- Exemplo: WordPress pode acessar Chatwoot via `http://chatwoot-rails-1:3000`.

## 4) Hot reload (frontend)

Com o ambiente rodando:

```bash
make docker_logs
```

Edite arquivos Vue/JS e recarregue o navegador.  
O `vite` deve refletir as mudanças sem rebuild completo.

Se o hot reload travar:

```bash
make docker_restart
```

## 5) Parar ambiente

```bash
make docker_down
```

## 6) Fluxo recomendado no dia a dia

1. `make docker_up`
2. `make docker_logs`
3. Editar código
4. Se necessário: `make docker_restart`
5. Finalizar: `make docker_down`

## 7) Comandos úteis

- Criar/preparar DB (rodando em Docker):
```bash
docker compose exec -T rails bundle exec rails db:prepare
```

- Criar/preparar DB (rodando Ruby local):
```bash
make db
```

- Console Rails local:
```bash
RAILS_ENV=development bundle exec rails console
```

- Restaurar backup `.sql` (formato `pg_dump custom`):
```bash
docker compose stop rails sidekiq
cat /caminho/backup-chatwoot.sql | docker compose exec -T postgres sh -lc 'export PGPASSWORD="$POSTGRES_PASSWORD"; pg_restore -U postgres -d chatwoot_dev --clean --if-exists --no-owner --no-privileges'
docker compose start rails sidekiq
docker compose exec -T rails bundle exec rails db:migrate
```

## 8) Widget no WordPress (snippet padrão Chatwoot)

Para usar o snippet padrão do Chatwoot no WordPress:

- Base URL local: `http://localhost:3000`
- Script padrão: `http://localhost:3000/packs/js/sdk.js`

Se `"/packs/js/sdk.js"` retornar `404` no ambiente Docker com Vite, gere o SDK padrão:

```bash
docker compose exec -T vite pnpm build:sdk
```

Observação:
- O arquivo é gerado em `public/packs/js/sdk.js` dentro do volume Docker `packs`.
- Se você remover volumes (`docker compose down -v`), rode o comando acima novamente.

## 9) Problemas comuns

- Erro de DB (`chatwoot_dev` não encontrado): rode `docker compose exec -T rails bundle exec rails db:prepare`.
- Mudança não aparece: verifique logs do `vite` e rode `make docker_restart`.
- Lentidão com rebuild: evite `docker compose up --build` no fluxo normal.

## 10) Pós-deploy (IMPORTANTE)

- Validar o SDK do widget em produção:
```bash
curl -I https://seu-dominio/packs/js/sdk.js
```
- Esperado: retorno `200 OK`.
