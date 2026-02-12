module AccountSettings
  def custom_menus
    normalize_custom_menus((settings || {})['custom_menus'])
  end

  def custom_menus=(value)
    normalized = normalize_custom_menus(value)
    self.settings = (settings || {}).merge('custom_menus' => normalized)
  end

  def branding_settings
    ((settings || {})['branding'] || {}).with_indifferent_access
  end

  def update_branding_settings!(attrs)
    merged = branding_settings.merge(attrs.stringify_keys)
    new_settings = (settings || {}).dup
    new_settings['branding'] = merged
    update!(settings: new_settings)
  end

  private

  def normalize_custom_menus(value)
    parse_custom_menus(value).filter_map { |item| normalize_custom_menu_item(item) }
  rescue JSON::ParserError
    []
  end

  def parse_custom_menus(value)
    return JSON.parse(value) if value.is_a?(String)
    return value if value.is_a?(Array)

    []
  end

  def normalize_custom_menu_item(item)
    return unless item.is_a?(Hash)

    label = item['label'] || item[:label]
    link = item['link'] || item[:link]
    return if label.blank? || link.blank?

    { 'label' => label.to_s.strip, 'link' => link.to_s.strip }
  end
end
