module BrandingConfigResolver
  BRANDING_KEYS = %w[LOGO LOGO_DARK LOGO_THUMBNAIL].freeze
  APPLE_ICON_SIZES = [57, 60, 72, 76, 114, 120, 144, 152, 180].freeze
  ANDROID_ICON_SIZES = [36, 48, 72, 96, 144, 192].freeze
  MS_ICON_SIZES = [144].freeze
  ACCOUNT_KEY_MAP = {
    'LOGO' => 'logo',
    'LOGO_DARK' => 'logo_dark',
    'LOGO_THUMBNAIL' => 'logo_thumbnail'
  }.freeze

  module_function

  def apply(config, host)
    return config unless config.respond_to?(:[])

    host_key = branding_host_key(host)
    BRANDING_KEYS.each do |key|
      next unless config.key?(key)

      resolved = branding_value_for(key, config[key], host_key)
      config[key] = resolved
    end
    config
  end

  def branding_value_for(key, value, host_key)
    account_state, account_value = account_branding_state(key)
    return nil if account_state == :removed

    host_specific = host_specific_value(value, host_key).presence
    account_specific = account_state == :set ? account_value : nil
    default_value = default_branding_value(value)

    resolved = if key == 'LOGO_THUMBNAIL'
                 domain_specific = domain_favicon_path(host_key).presence
                 domain_specific || account_specific || host_specific || default_value
               else
                 account_specific || host_specific || default_value
               end

    uploads_branding_value(key, host_key, resolved)
  end

  def branding_host_key(host)
    return 'default' if host.blank?

    normalized = host.to_s.strip.downcase
    normalized = normalized.split(':').first
    normalized.delete_prefix('www.').presence || 'default'
  end

  def account_branding_value(key)
    _state, value = account_branding_state(key)
    value
  end

  def account_branding_state(key)
    account = Current.account
    return [:unset, nil] unless account.respond_to?(:branding_settings)

    branding = account.branding_settings
    branding_key = ACCOUNT_KEY_MAP[key]
    return [:unset, nil] unless branding.respond_to?(:key?) && branding.key?(branding_key)

    value = branding[branding_key]
    return [:removed, nil] if value.blank?

    [:set, value]
  end

  def host_specific_value(value, host_key)
    return unless value.is_a?(Hash)

    value[host_key]
  end

  def default_branding_value(value)
    return value unless value.is_a?(Hash)

    value['default'] || value.values.first
  end

  def uploads_branding_value(key, host_key, resolved)
    candidate = uploads_branding_path(resolved)
    return candidate if candidate.present?

    case key
    when 'LOGO'
      account_logo_path('-light') || any_logo_path('-light')
    when 'LOGO_DARK'
      account_logo_path('-dark') || any_logo_path('-dark')
    when 'LOGO_THUMBNAIL'
      domain_favicon_path(host_key) || account_logo_path('-favico') || any_logo_path('-favico')
    end
  end

  def uploads_branding_path(value)
    return value if value.is_a?(String) && value.include?('/uploads/branding/')

    return unless value.is_a?(Hash)

    value.values.find { |entry| entry.is_a?(String) && entry.include?('/uploads/branding/') }
  end

  def account_logo_path(suffix)
    account = Current.account
    return if account.blank?

    uploads_branding_path_from_pattern("account-#{account.id}#{suffix}.*")
  end

  def any_logo_path(suffix)
    uploads_branding_path_from_pattern("account-*#{suffix}.*") ||
      uploads_branding_path_from_pattern("*#{suffix}.*")
  end

  def uploads_branding_path_from_pattern(pattern)
    file = Dir.glob(Rails.public_path.join('uploads', 'branding', pattern)).first
    file&.sub(Rails.public_path.to_s, '')
  end

  def domain_favicon_path(host_key)
    return if host_key.blank?

    pattern = Rails.public_path.join('uploads', 'branding', "#{host_key}-favico.*")
    file = Dir.glob(pattern).first
    return unless file

    file.sub(Rails.public_path.to_s, '')
  end

  def icon_path(favicon_url, icon_basename)
    return "/#{icon_basename}.png" if icon_basename.blank?
    return "/#{icon_basename}.png" unless favicon_url.is_a?(String)
    return "/#{icon_basename}.png" unless favicon_url.include?('/uploads/branding/') && favicon_url.end_with?('-favico.ico')

    base = favicon_url.delete_suffix('-favico.ico')
    "#{base}-#{icon_basename}.png"
  end
end
