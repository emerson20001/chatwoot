require 'administrate/field/base'

class WordpressBlogField < Administrate::Field::Base
  def wordpress_blog
    item = if data.is_a?(Hash)
             data
           elsif data.respond_to?(:to_h)
             data.to_h
           end
    return {} unless item.is_a?(Hash)

    {
      'blog_id' => value_for(item, :blog_id),
      'domain' => value_for(item, :domain),
      'name' => value_for(item, :name),
      'slug' => value_for(item, :slug)
    }.compact
  end

  private

  def value_for(item, key)
    value = item[key.to_s] || item[key]
    return if value.blank?

    value.to_s.strip
  end
end
