require 'cgi'

class Inboxes::EvolutionWhatsappProvisionService
  class Error < StandardError; end

  REQUEST_TIMEOUT_SECONDS = 20

  def initialize(inbox:)
    @inbox = inbox
    @api_url = env_for('EVOLUTION_API_URL').to_s.chomp('/')
    @api_key = env_for('EVOLUTION_API_KEY').to_s
    @chatwoot_url = env_for('EVOLUTION_CHATWOOT_URL', ENV.fetch('FRONTEND_URL', '')).to_s.chomp('/')
  end

  def call
    validate_configuration!

    instance_name = next_instance_name
    update_inbox_webhook!(instance_name)
    create_instance!(instance_name)
    configure_chatwoot_integration!(instance_name)
  rescue Error
    raise
  rescue StandardError => e
    raise Error, e.message
  end

  private

  def validate_configuration!
    raise Error, 'EVOLUTION_API_URL is not configured' if @api_url.blank?
    raise Error, 'EVOLUTION_API_KEY is not configured' if @api_key.blank?
    raise Error, 'EVOLUTION_CHATWOOT_URL or FRONTEND_URL is not configured' if @chatwoot_url.blank?
    raise Error, 'Current user API access token was not found' if access_token.blank?
  end

  def next_instance_name
    base_name = "instance#{@inbox.account_id}"
    names = fetch_instances.map { |instance| instance['name'] }.compact
    return base_name unless names.include?(base_name)

    suffix = 1
    loop do
      candidate = "#{base_name}_#{suffix}"
      return candidate unless names.include?(candidate)

      suffix += 1
    end
  end

  def fetch_instances
    response = HTTParty.get(
      "#{@api_url}/instance/fetchInstances",
      headers: request_headers,
      timeout: REQUEST_TIMEOUT_SECONDS
    )
    payload = parse_response!(response)
    payload.is_a?(Array) ? payload : []
  end

  def create_instance!(instance_name)
    response = HTTParty.post(
      "#{@api_url}/instance/create",
      headers: request_headers,
      timeout: REQUEST_TIMEOUT_SECONDS,
      body: {
        instanceName: instance_name,
        integration: 'WHATSAPP-BAILEYS',
        qrcode: true
      }.to_json
    )
    parse_response!(response)
  end

  def configure_chatwoot_integration!(instance_name)
    response = HTTParty.post(
      "#{@api_url}/chatwoot/set/#{CGI.escape(instance_name)}",
      headers: request_headers,
      timeout: REQUEST_TIMEOUT_SECONDS,
      body: {
        enabled: true,
        autoCreate: true,
        url: @chatwoot_url,
        accountId: @inbox.account_id.to_s,
        token: access_token,
        nameInbox: @inbox.name,
        signMsg: false,
        reopenConversation: false,
        conversationPending: false,
        mergeBrazilContacts: false,
        importContacts: false,
        importMessages: false,
        daysLimitImportMessages: 7
      }.to_json
    )
    parse_response!(response)
  end

  def update_inbox_webhook!(instance_name)
    webhook_url = "#{@api_url}/chatwoot/webhook/#{CGI.escape(instance_name)}"
    @inbox.channel.update!(webhook_url: webhook_url)
  end

  def request_headers
    {
      'Content-Type' => 'application/json',
      'apikey' => @api_key
    }
  end

  def parse_response!(response)
    return response.parsed_response if response.success?

    parsed_response = response.parsed_response.is_a?(Hash) ? response.parsed_response : {}
    message =
      parsed_response.dig('response', 'message') ||
      parsed_response.dig('message') ||
      response.body
    raise Error, "Evolution API error (#{response.code}): #{message}"
  end

  def access_token
    @access_token ||= Current.user&.access_token&.token
  end

  def env_for(base_key, fallback = '')
    env_key = "#{base_key}_#{Rails.env.upcase}"
    ENV.fetch(env_key, ENV.fetch(base_key, fallback))
  end
end
