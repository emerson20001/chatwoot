require 'administrate/field/base'

class CustomMenusField < Administrate::Field::Base
  def custom_menus
    return [] unless data.is_a?(Array)

    data.filter_map do |item|
      next unless item.is_a?(Hash)

      label = item['label'] || item[:label]
      link = item['link'] || item[:link]
      next if label.blank? || link.blank?

      { 'label' => label.to_s, 'link' => link.to_s }
    end
  end
end
