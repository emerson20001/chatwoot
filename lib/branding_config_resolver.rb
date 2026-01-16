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
      next if resolved.nil?

      config[key] = resolved
    end
    config
  end

  def branding_value_for(key, value, host_key)
    host_specific = host_specific_value(value, host_key).presence
    account_specific = account_branding_value(key).presence
    default_value = default_branding_value(value)

    return host_specific || account_specific || default_value unless key == 'LOGO_THUMBNAIL'

    domain_specific = domain_favicon_path(host_key).presence
    domain_specific || account_specific || host_specific || default_value
  end

  def branding_host_key(host)
    return 'default' if host.blank?

    normalized = host.to_s.strip.downcase
    normalized = normalized.split(':').first
    normalized.delete_prefix('www.').presence || 'default'
  end

  def account_branding_value(key)
    account = Current.account
    return unless account.respond_to?(:branding_settings)

    branding = account.branding_settings
    branding[ACCOUNT_KEY_MAP[key]]
  end

  def host_specific_value(value, host_key)
    return unless value.is_a?(Hash)

    value[host_key]
  end

  def default_branding_value(value)
    return value unless value.is_a?(Hash)

    value['default'] || value.values.first
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
