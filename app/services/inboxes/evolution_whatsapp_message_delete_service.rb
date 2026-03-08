class Inboxes::EvolutionWhatsappMessageDeleteService
  REQUEST_TIMEOUT_SECONDS = 10

  def initialize(message:)
    @message = message
  end

  def call
    return unless evolution_whatsapp_message?
    return if channel.webhook_url.blank?

    HTTParty.post(
      channel.webhook_url,
      headers: { 'Content-Type' => 'application/json' },
      timeout: REQUEST_TIMEOUT_SECONDS,
      body: payload.to_json
    )
  end

  private

  def evolution_whatsapp_message?
    return false unless @message.inbox.channel_type == 'Channel::Api'

    channel.additional_attributes&.with_indifferent_access&.[](:provider) == 'whatsapp_evo'
  end

  def channel
    @channel ||= @message.inbox.channel
  end

  def payload
    @message.reload
    @message.webhook_data.merge(event: 'message_updated')
  end
end
