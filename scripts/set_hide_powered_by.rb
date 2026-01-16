InstallationConfig.find_or_initialize_by(name: 'HIDE_POWERED_BY').update(value: true)
GlobalConfig.clear_cache
puts 'HIDE_POWERED_BY ativado!'
