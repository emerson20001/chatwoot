InstallationConfig.find_or_initialize_by(name: 'DYNAMIC_TITLE_FROM_DOMAIN').update(value: true)
GlobalConfig.clear_cache
puts 'DYNAMIC_TITLE_FROM_DOMAIN ativado!'
