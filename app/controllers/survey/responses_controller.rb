class Survey::ResponsesController < ActionController::Base
  include BrandingOverrides
  before_action :set_conversation
  before_action :set_global_config
  def show; end

  private

  def set_conversation
    @conversation = Conversation.find_by!(uuid: params[:id])
    Current.account = @conversation.account
  rescue ActiveRecord::RecordNotFound
    render plain: '', status: :not_found
  end

  def set_global_config
    config = GlobalConfig.get(
      'LOGO_THUMBNAIL',
      'BRAND_NAME',
      'WIDGET_BRAND_URL',
      'INSTALLATION_NAME',
      'HIDE_POWERED_BY',
      'DYNAMIC_TITLE_FROM_DOMAIN'
    )
    @global_config = apply_branding_overrides(config, request.host)
  end
end
