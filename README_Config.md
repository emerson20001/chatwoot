# Guia Completo — Patch Hide Powered By + Dynamic Title (Chatwoot Enterprise Custom)

Este documento contém o passo a passo completo para aplicar manualmente todas as modificações dos patches:

1. Remover “Powered by Chatwoot”
2. Adicionar título dinâmico baseado no domínio (Dynamic Title From Domain)
3. Aplicar título dinâmico também no widget (/widget?...)


## 1. EDITAR config/installation_config.yml

Adicionar duas novas flags globais: HIDE_POWERED_BY e DYNAMIC_TITLE_FROM_DOMAIN.

Adicionar abaixo de BRAND_NAME:

```yaml
- name: HIDE_POWERED_BY
  value: false
  display_title: 'Hide Powered By'
  description: 'Hide Chatwoot branding across the widget and surveys'
  type: boolean

- name: DYNAMIC_TITLE_FROM_DOMAIN
  value: false
  display_title: 'Dynamic Title From Domain'
  description: 'Sets the dashboard title to "<domain> — Chatwoot"'
  type: boolean
```

## 2. EDITAR app/controllers/api/v1/widget/configs_controller.rb

Adicionar:

```ruby
'HIDE_POWERED_BY'
```

## 3. EDITAR app/controllers/dashboard_controller.rb

Adicionar abaixo de BRAND_NAME:

```ruby
HIDE_POWERED_BY
DYNAMIC_TITLE_FROM_DOMAIN
```

## 4. EDITAR app/controllers/survey/responses_controller.rb

Adicionar no GlobalConfig.get:

```ruby
'HIDE_POWERED_BY'
```

## 5. EDITAR app/controllers/widgets_controller.rb

Adicionar:

```ruby
'HIDE_POWERED_BY'
```

## 6. EDITAR app/javascript/shared/components/Branding.vue

Adicionar:

```js
import { parseBoolean } from '@chatwoot/utils';
```

Adicionar no globalConfig:

```js
HIDE_POWERED_BY: hidePoweredBy,
```

Adicionar método:

```js
shouldHideBranding() {
  return this.disableBranding || this.globalConfig.hidePoweredBy;
}
```

Trocar:

```html
v-if="globalConfig.brandName && !disableBranding"
```

por:

```html
v-if="globalConfig.brandName && !shouldHideBranding"
```

## 7. EDITAR app/javascript/shared/store/globalConfig.js

Adicionar:

```js
HIDE_POWERED_BY: hidePoweredBy,
```

E:

```js
hidePoweredBy: parseBoolean(hidePoweredBy),
```

## 8. EDITAR app/views/api/v1/widget/configs/create.json.jbuilder

Trocar:

```ruby
json.disable_branding @web_widget.inbox.account.feature_enabled?('disable_branding')
```

por:

```ruby
json.disable_branding @web_widget.inbox.account.feature_enabled?('disable_branding') || @global_config['HIDE_POWERED_BY']
```

## 9. EDITAR app/views/widgets/show.html.erb

Trocar:

```ruby
disableBranding: <%= @web_widget.inbox.account.feature_enabled?('disable_branding') %>
```

por:

```ruby
disableBranding: <%= @web_widget.inbox.account.feature_enabled?('disable_branding') || @global_config['HIDE_POWERED_BY'] %>
```

## 10. EDITAR LAYOUT PRINCIPAL — app/views/layouts/application.html.erb

Substituir `<title>Chatwoot</title>` por:

```erb
<% dynamic_title_enabled = GlobalConfig.get('DYNAMIC_TITLE_FROM_DOMAIN') %>
<% if dynamic_title_enabled.to_s == 'true' %>
  <% raw_domain = request.host.to_s.gsub(/^www\./, '') %>
  <% cleaned = raw_domain.presence || 'Chatwoot' %>
  <title><%= "#{cleaned} — Chatwoot" %></title>
<% else %>
  <title>Chatwoot</title>
<% end %>
```

## 11. EDITAR app/views/layouts/vueapp.html.erb

```erb
<% dynamic_title_enabled = @global_config['DYNAMIC_TITLE_FROM_DOMAIN'] %>
<% installation_name = if dynamic_title_enabled.to_s == 'true'
                         raw_domain = request.host.to_s.gsub(/^www\./, '')
                         raw_domain.present? ? "#{raw_domain} - Chatwoot" : 'Chatwoot'
                       else
                         @global_config['INSTALLATION_NAME']
                       end %>
<title><%= installation_name %></title>
```

## 12. CRIAR scripts/set_hide_powered_by.rb

```ruby
InstallationConfig.find_or_initialize_by(name: 'HIDE_POWERED_BY').update(value: true)
GlobalConfig.clear_cache
puts "HIDE_POWERED_BY ativado!"
```

Executar:

```bash
rails runner scripts/set_hide_powered_by.rb
```

## 13. CRIAR scripts/set_dynamic_title.rb

```ruby
InstallationConfig.find_or_initialize_by(name: 'DYNAMIC_TITLE_FROM_DOMAIN').update(value: true)
GlobalConfig.clear_cache
puts "DYNAMIC_TITLE_FROM_DOMAIN ativado!"
```

Executar:

```bash
rails runner scripts/set_dynamic_title.rb
```

## 14. PASSO EXTRA — Aplicar TÍTULO DINÂMICO também no Widget (/widget?...):

### 1 — Expor flag ao widget

Garantir em widgets_controller:

```ruby
'DYNAMIC_TITLE_FROM_DOMAIN'
```

### 2 — Garantir que a flag chegue ao front

`show.html.erb` já expõe `@global_config`.

### 3 — Calcular o título do widget

```erb
<% dynamic_title_enabled = @global_config['DYNAMIC_TITLE_FROM_DOMAIN'] %>
<% widget_title = if dynamic_title_enabled.to_s == 'true'
                    raw_domain = request.host.to_s.gsub(/^www\./, '')
                    raw_domain.present? ? "#{raw_domain} — Chatwoot" : 'Chatwoot'
                  else
                    @global_config['INSTALLATION_NAME']
                  end %>
<title><%= widget_title %></title>
```

### 4 — Validar

```bash
rails runner scripts/set_dynamic_title.rb
```

Acessar:

```
http://localhost:3000/widget?...
```

### 5 — Repetir lógica para outras telas

- surveys  
- super_admin  
- qualquer outro layout  

---

# **FIM DO DOCUMENTO**
