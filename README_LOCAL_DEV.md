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
sudo apt install -y rbenv
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

- Criar/preparar DB:
```bash
make db
```

- Console Rails local:
```bash
RAILS_ENV=development bundle exec rails console
```

## 8) Problemas comuns

- Erro de DB (`chatwoot_dev` não encontrado): rode `make db`.
- Mudança não aparece: verifique logs do `vite` e rode `make docker_restart`.
- Lentidão com rebuild: evite `docker compose up --build` no fluxo normal.

