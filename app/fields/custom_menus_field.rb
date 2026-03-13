require 'administrate/field/base'

class CustomMenusField < Administrate::Field::Base
  def custom_menus
    menus = if data.is_a?(Array)
              data
            elsif data.respond_to?(:to_h)
              data.to_h.values
            else
              []
            end

    menus.filter_map do |item|
      next unless item.is_a?(Hash)

      label = item['label'] || item[:label]
      link = item['link'] || item[:link]
      next if label.blank? || link.blank?

      {
        'label' => label.to_s,
        'link' => link.to_s,
        'token_id' => normalize_text(item, :token_id),
        'blog_id' => normalize_text(item, :blog_id),
        'url_blog_id' => normalize_text(item, :url_blog_id),
        'visible_for_administrator' => normalize_visibility(item, :visible_for_administrator),
        'visible_for_agent' => normalize_visibility(item, :visible_for_agent)
      }.compact
    end
  end

  private

  def normalize_visibility(item, key)
    raw_value = if item.key?(key.to_s)
                  item[key.to_s]
                elsif item.key?(key)
                  item[key]
                end
    return true if raw_value.nil?

    ActiveModel::Type::Boolean.new.cast(raw_value)
  end

  def normalize_text(item, key)
    raw_value = if item.key?(key.to_s)
                  item[key.to_s]
                elsif item.key?(key)
                  item[key]
                end
    return if raw_value.blank?

    raw_value.to_s.strip
  end
end
