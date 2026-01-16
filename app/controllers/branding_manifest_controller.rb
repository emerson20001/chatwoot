class BrandingManifestController < ActionController::Base
  def show
    set_branding_account
    config = GlobalConfig.get('INSTALLATION_NAME', 'LOGO_THUMBNAIL')
    installation_name = config['INSTALLATION_NAME'].presence || 'Chatwoot'
    favicon_url = config['LOGO_THUMBNAIL']

    render json: {
      name: installation_name,
      short_name: installation_name,
      icons: manifest_icons(favicon_url),
      start_url: '/',
      display: 'standalone',
      background_color: '#1f93ff',
      theme_color: '#1f93ff'
    }
  end

  private

  def set_branding_account
    return if params[:account_id].blank?

    Current.account = Account.find_by(id: params[:account_id])
  end

  def manifest_icons(favicon_url)
    return [] if favicon_url.blank?

    BrandingConfigResolver::ANDROID_ICON_SIZES.map do |size|
      {
        src: BrandingConfigResolver.icon_path(favicon_url, "android-icon-#{size}x#{size}"),
        sizes: "#{size}x#{size}",
        type: 'image/png',
        density: manifest_density(size)
      }
    end
  end

  def manifest_density(size)
    {
      36 => '0.75',
      48 => '1.0',
      72 => '1.5',
      96 => '2.0',
      144 => '3.0',
      192 => '4.0'
    }[size] || '1.0'
  end
end
