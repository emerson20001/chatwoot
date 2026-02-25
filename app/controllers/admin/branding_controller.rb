require 'stringio'

class Admin::BrandingController < ApplicationController
  before_action :authenticate_user!
  before_action :set_account_context
  before_action :set_configs

  BRANDING_CONFIGS = {
    logo: 'LOGO',
    logo_dark: 'LOGO_DARK',
    logo_thumbnail: 'LOGO_THUMBNAIL'
  }.freeze

  FILENAME_SUFFIX = {
    logo: '-light',
    logo_dark: '-dark',
    logo_thumbnail: '-favico'
  }.freeze

  def show
    respond_to do |format|
      format.html
      format.json { render_configs_json }
    end
  end

  def update
    changes_applied = apply_branding_updates

    respond_to do |format|
      if changes_applied
        GlobalConfig.clear_cache
        format.html { redirect_to admin_branding_path(account_id: @account&.id), notice: I18n.t('admin.branding.flash.success') }
        format.json { render_configs_json }
      else
        format.html do
          flash.now[:alert] = I18n.t('admin.branding.flash.no_changes')
          render :show, status: :unprocessable_entity
        end
        format.json { render_configs_json(status: :unprocessable_entity) }
      end
    end
  end

  private

  def set_account_context
    @account = resolve_account_from_scope
    @domain_label = resolve_domain_label
    @domain_key = resolve_domain_key(@domain_label)
    if @account
      Current.account = @account
      return
    end

    respond_to do |format|
      format.html do
        redirect_to(root_path, alert: I18n.t('admin.branding.flash.account_missing'))
      end
      format.json do
        render json: { error: 'Account not found' }, status: :not_found
      end
    end
    false
  end

  def resolve_account_from_scope
    return nil unless current_user

    scoped_accounts = current_user.accounts
    account_id = params[:account_id].presence || scoped_accounts.first&.id
    return nil unless account_id

    scoped_accounts.find(account_id)
  rescue ActiveRecord::RecordNotFound
    nil
  end

  def resolve_domain_label
    params[:domain].presence || @account&.domain.presence || request.host.presence || 'default'
  end

  def sanitize_domain_key(source)
    source.to_s.strip.downcase.presence || 'default'
  end

  def set_configs
    @account_branding = current_branding_settings
    @resolved_branding = BRANDING_CONFIGS.each_with_object({}) do |(key, config_name), memo|
      memo[key] = if @account_branding.key?(key.to_s)
                    @account_branding[key.to_s]
                  else
                    installation_branding_default(config_name)
                  end
    end
  end

  def current_branding_settings
    @account.branding_settings.dup
  end

  def installation_branding_default(config_name)
    value = InstallationConfig.find_by(name: config_name)&.value
    return value unless value.is_a?(Hash)

    value[@domain_key] || value['default'] || value.values.first
  end

  def branding_params
    params.fetch(:branding, {}).permit(
      logo: %i[url file remove],
      logo_dark: %i[url file remove],
      logo_thumbnail: %i[url file remove]
    )
  end

  def processed_value(field_key, attributes)
    return :remove if remove_requested?(attributes)

    if attributes[:file].present?
      store_upload(field_key, attributes[:file])
    else
      attributes[:url].presence
    end
  end

  def remove_requested?(attributes)
    ActiveModel::Type::Boolean.new.cast(attributes[:remove])
  end

  def storage_prefix
    "account-#{@account.id}"
  end

  def store_upload(field_key, file)
    suffix = FILENAME_SUFFIX[field_key.to_sym] || ''
    upload_dir = Rails.public_path.join('uploads', 'branding')
    FileUtils.mkdir_p(upload_dir)

    if field_key.to_sym == :logo_thumbnail
      filename = "#{storage_prefix}#{suffix}.ico"
      destination = upload_dir.join(filename)
      write_favicon(file, destination)
      write_icon_variants(file, upload_dir, storage_prefix)
      write_domain_favicon(file, upload_dir, suffix)
      write_domain_icon_variants(file, upload_dir)
      return "/uploads/branding/#{filename}"
    end

    extension = File.extname(file.original_filename).downcase
    extension = '.png' if extension.blank?
    filename = "#{storage_prefix}#{suffix}#{extension}"
    destination = upload_dir.join(filename)
    write_binary(file, destination)
    "/uploads/branding/#{filename}"
  end

  def write_binary(file, destination)
    file.rewind if file.respond_to?(:rewind)
    File.binwrite(destination, file.read)
  ensure
    file.rewind if file.respond_to?(:rewind)
  end

  def write_domain_favicon(file, upload_dir, suffix)
    domain_prefix = domain_storage_prefix
    return if domain_prefix.blank?

    filename = "#{domain_prefix}#{suffix}.ico"
    destination = upload_dir.join(filename)
    write_favicon(file, destination)
  end

  def write_domain_icon_variants(file, upload_dir)
    domain_prefix = domain_storage_prefix
    return if domain_prefix.blank?

    write_icon_variants(file, upload_dir, domain_prefix)
  end

  def domain_storage_prefix
    @domain_storage_prefix ||= begin
      host_key = BrandingConfigResolver.branding_host_key(@domain_label)
      host_key unless host_key.blank? || host_key == 'default'
    rescue NameError
      sanitized = sanitize_domain_key(@domain_label)
      sanitized == 'default' ? nil : sanitized
    end
  end

  def write_favicon(file, destination)
    require 'mini_magick'
    blob = extract_file_blob(file)
    image = MiniMagick::Image.read(blob)
    image.format 'ico'
    image.write(destination)
  rescue StandardError => e
    Rails.logger.error("Branding favicon conversion failed: #{e.message}")
    write_binary(StringIO.new(blob || ''), destination)
  ensure
    rewind_uploaded_file(file)
  end

  def write_icon_variants(file, upload_dir, prefix)
    require 'mini_magick'
    blob = extract_file_blob(file)
    return if blob.blank?

    BrandingConfigResolver::APPLE_ICON_SIZES.each do |size|
      write_icon_variant(blob, upload_dir.join("#{prefix}-apple-icon-#{size}x#{size}.png"), size)
    end
    BrandingConfigResolver::ANDROID_ICON_SIZES.each do |size|
      write_icon_variant(blob, upload_dir.join("#{prefix}-android-icon-#{size}x#{size}.png"), size)
    end
    BrandingConfigResolver::MS_ICON_SIZES.each do |size|
      write_icon_variant(blob, upload_dir.join("#{prefix}-ms-icon-#{size}x#{size}.png"), size)
    end
  rescue StandardError => e
    Rails.logger.error("Branding icon generation failed: #{e.message}")
  ensure
    rewind_uploaded_file(file)
  end

  def write_icon_variant(blob, destination, size)
    image = MiniMagick::Image.read(blob)
    image.resize "#{size}x#{size}"
    image.format 'png'
    image.write(destination)
  end

  def extract_file_blob(file)
    if file.respond_to?(:tempfile)
      file.tempfile.rewind
      file.tempfile.read
    else
      file.rewind if file.respond_to?(:rewind)
      file.read
    end
  end

  def rewind_uploaded_file(file)
    if file.respond_to?(:tempfile)
      file.tempfile.rewind
    elsif file.respond_to?(:rewind)
      file.rewind
    end
  end

  def persist_branding_value(field_key, value)
    @account.update_branding_settings!(field_key => value)
    config_name = BRANDING_CONFIGS[field_key.to_sym]
    store_installation_branding_value(config_name, value)
  end

  def render_configs_json(status: :ok)
    payload = BRANDING_CONFIGS.each_with_object({}) do |(key, _), memo|
      memo[key] = @resolved_branding[key]
    end

    render json: { configs: payload, domain: @domain_label, account_id: @account&.id }, status: status
  end

  def apply_branding_updates
    applied = false

    branding_params.each do |key, attributes|
      next unless BRANDING_CONFIGS[key.to_sym]

      new_value = processed_value(key, attributes)
      if new_value == :remove
        persist_branding_value(key, nil)
        applied = true
        next
      end
      next if new_value.blank?

      persist_branding_value(key, new_value)
      applied = true
    end

    set_configs
    applied
  end

  def resolve_domain_key(source)
    BrandingConfigResolver.branding_host_key(source)
  rescue NameError
    sanitize_domain_key(source)
  end

  def store_installation_branding_value(config_name, value)
    return if config_name.blank? || value.blank?

    config = InstallationConfig.find_or_initialize_by(name: config_name)
    payload = normalize_installation_branding_value(config.value)
    payload[account_branding_key] = value if account_branding_key
    if @domain_key.present? && @domain_key != 'default'
      payload[@domain_key] = value
    else
      payload['default'] = value
    end
    config.value = payload
    config.save!
  end

  def normalize_installation_branding_value(existing_value)
    case existing_value
    when Hash
      existing_value.with_indifferent_access
    when nil, ''
      {}.with_indifferent_access
    else
      { 'default' => existing_value }.with_indifferent_access
    end
  end

  def account_branding_key
    return unless @account&.id

    "account-#{@account.id}"
  end
end
