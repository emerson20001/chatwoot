# Chatwoot Custom — v4.8.0  
**Versão personalizada com suporte nativo ao recurso HIDE_POWERED_BY (modo enterprise)**  
Este repositório contém uma versão modificada do Chatwoot 4.8.0 com o patch exclusivo para remoção completa do rodapé "*Powered by Chatwoot*" em:

- Widget de atendimento  
- Formulário de CSAT (survey)  
- Dashboard / página do agente  
- Config API do widget  
- JS embed (`window.chatwootWebChannel.disableBranding`)  

A função de ocultar o branding é ativada por uma nova chave oficial no sistema:

```
HIDE_POWERED_BY = true
```

Essa configuração adiciona ao Chatwoot Community Edition um comportamento equivalente ao recurso **Enterprise disable_branding**, funcionando de maneira 100% nativa, sem hacks no bundle.

---

# 🚀 Funcionalidades adicionadas nesta versão

### ✔ **Nova configuração persistente no banco**
Registrada em `installation_config.yml` como:

```yaml
- name: HIDE_POWERED_BY
  value: false
  type: boolean
  description: 'Hide Chatwoot branding across the widget and surveys'
```

### ✔ **Backend ajustado para transmitir a flag ao frontend**
A flag é aplicada nos seguintes componentes:

- Widget JSON (`/api/v1/widget/config`)
- HTML embed (`widgets/show.html.erb`)
- Dashboard (`dashboard_controller`)
- Surveys de CSAT (`survey/responses_controller`)

Sempre que a flag está ativa, o Chatwoot responde:

```
disable_branding: true
```

Como se fosse a versão Enterprise.

---

# 🎨 Como o frontend interpreta a remoção do branding

O componente Vue `Branding.vue` foi modificado para:

- Ler a flag global `hidePoweredBy`
- Interpretar corretamente valores booleanos com `parseBoolean`
- Unificar a lógica:

```js
shouldHideBranding = disableBranding || globalConfig.hidePoweredBy
```

Assim, qualquer uma das flags remove o footer do widget.

---

# 🧩 Patch oficial incluído: `hide-powered-by.patch`

Todo o conjunto de modificações está consolidado em um único arquivo:

```
hide-powered-by.patch
```

Esse arquivo aplica:

- Alterações no backend
- Alterações no frontend (Vue + GlobalConfig + branding)
- Registros da configuração
- Criação do script de ativação

---

# ⚙️ Como aplicar o patch

## ▶️ **1. Aplicar patch completo**

Use isso quando estiver instalando do zero:

```
git apply hide-powered-by.patch
```

---

## ▶️ **2. Aplicar patch ignorando o script (útil quando o arquivo já existe)**

Quando atualizar o Chatwoot para uma versão futura e o arquivo `scripts/set_hide_powered_by.rb` já existir:

```
git apply --exclude=scripts/set_hide_powered_by.rb hide-powered-by.patch
```

Esse comando reaplica todas as alterações, exceto recriar o script.

---

## ▶️ **3. Ativar a configuração no banco**

Depois que o patch estiver aplicado, rode:

```
rails runner scripts/set_hide_powered_by.rb
```

Esse script:

1. Cria/atualiza a chave `HIDE_POWERED_BY`
2. Define o valor como `true`
3. Limpa o cache global
4. Exibe no terminal:

```
HIDE_POWERED_BY ativado!
```

---

# 🔄 Atualização do Chatwoot para versões futuras

Quando atualizar o Chatwoot (por exemplo, v4.9.0, v5.0 etc.):

1. Faça pull da versão nova  
2. Reaplique o patch:  

```
git apply hide-powered-by.patch
```

Se houver conflitos apenas no script:

```
git apply --exclude=scripts/set_hide_powered_by.rb hide-powered-by.patch
```

3. Rebuild dos assets:  

```
rm -rf public/vite public/packs public/assets tmp/cache .vite .cache
pnpm install
pnpm run build:sdk --force
BUILD_MODE=production pnpm exec vite build --force
rails assets:precompile
```

4. Reative a flag (se a DB for nova):

```
rails runner scripts/set_hide_powered_by.rb
```

---

# 🧪 Como verificar se o patch está funcionando

## ▶️ 1. Abra o payload JSON do widget:

```
/api/v1/widget/config?website_token=TOKEN
```

Você deve ver:

```json
"disable_branding": true
```

---

## ▶️ 2. Teste diretamente no iframe do widget

No console:

```js
window.chatwootWebChannel.disableBranding
```

Resultado esperado:

```
true
```

---

# 📦 Sobre esta versão (base utilizada)

Este repositório se baseia no Chatwoot:

```
Version: 4.8.0
Commit: 4e9f644 (stable)
Released: 3 semanas atrás
Node recomendado: 23.x
Node usado: 22.21.0
```

Com todas as correções do patch integradas.

---

# 🔐 Licença

Baseado em Chatwoot (MIT License).  
Modificações adicionais por Emerson Alves.

---

# 📣 Suporte

Dúvidas sobre o patch, aplicação ou build?  
Me peça aqui no Chat que ajusto qualquer parte do processo.
