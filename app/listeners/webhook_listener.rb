class WebhookListener < BaseListener
  def conversation_status_changed(event)
    conversation = extract_conversation_and_account(event)[0]
    changed_attributes = extract_changed_attributes(event)
    inbox = conversation.inbox
    payload = conversation.webhook_data.merge(event: __method__.to_s, changed_attributes: changed_attributes)
    deliver_webhook_payloads(payload, inbox)
  end

  def conversation_updated(event)
    conversation = extract_conversation_and_account(event)[0]
    changed_attributes = extract_changed_attributes(event)
    inbox = conversation.inbox
    payload = conversation.webhook_data.merge(event: __method__.to_s, changed_attributes: changed_attributes)
    deliver_webhook_payloads(payload, inbox)
  end

  def conversation_created(event)
    conversation = extract_conversation_and_account(event)[0]
    inbox = conversation.inbox
    payload = conversation.webhook_data.merge(event: __method__.to_s)
    deliver_webhook_payloads(payload, inbox)
  end

  def message_created(event)
    message = extract_message_and_account(event)[0]
    inbox = message.inbox

    return unless message.webhook_sendable?

    payload = message.webhook_data.merge(event: __method__.to_s)
    deliver_webhook_payloads(payload, inbox)
  end

  def message_updated(event)
    message = extract_message_and_account(event)[0]
    inbox = message.inbox

    return unless message.webhook_sendable?

    payload = message.webhook_data.merge(event: __method__.to_s)
    deliver_webhook_payloads(payload, inbox)
  end

  def webwidget_triggered(event)
    contact_inbox = event.data[:contact_inbox]
    inbox = contact_inbox.inbox

    payload = contact_inbox.webhook_data.merge(event: __method__.to_s)
    payload[:event_info] = event.data[:event_info]
    deliver_webhook_payloads(payload, inbox)
  end

  def contact_created(event)
    contact, account = extract_contact_and_account(event)
    payload = contact.webhook_data.merge(event: __method__.to_s)
    deliver_account_webhooks(payload, account)
  end

  def contact_updated(event)
    contact, account = extract_contact_and_account(event)
    changed_attributes = extract_changed_attributes(event)
    return if changed_attributes.blank?

    payload = contact.webhook_data.merge(event: __method__.to_s, changed_attributes: changed_attributes)
    deliver_account_webhooks(payload, account)
  end

  def inbox_created(event)
    inbox, account = extract_inbox_and_account(event)
    inbox_webhook_data = Inbox::EventDataPresenter.new(inbox).push_data
    payload = inbox_webhook_data.merge(event: __method__.to_s)
    deliver_account_webhooks(payload, account)
  end

  def inbox_updated(event)
    inbox, account = extract_inbox_and_account(event)
    changed_attributes = extract_changed_attributes(event)
    return if changed_attributes.blank?

    inbox_webhook_data = Inbox::EventDataPresenter.new(inbox).push_data
    payload = inbox_webhook_data.merge(event: __method__.to_s, changed_attributes: changed_attributes)
    deliver_account_webhooks(payload, account)
  end

  def conversation_typing_on(event)
    handle_typing_status(__method__.to_s, event)
  end

  def conversation_typing_off(event)
    handle_typing_status(__method__.to_s, event)
  end

  private

  def handle_typing_status(event_name, event)
    conversation = event.data[:conversation]
    user = event.data[:user]
    inbox = conversation.inbox

    payload = {
      event: event_name,
      user: user.webhook_data,
      conversation: conversation.webhook_data,
      is_private: event.data[:is_private] || false
    }
    deliver_webhook_payloads(payload, inbox)
  end

  def deliver_account_webhooks(payload, account)
    account.webhooks.account_type.each do |webhook|
      next unless webhook.subscriptions.include?(payload[:event])

      WebhookJob.perform_later(webhook.url, payload)
    end
  end

  def deliver_api_inbox_webhooks(payload, inbox)
    return unless inbox.channel_type == 'Channel::Api'
    return if inbox.channel.webhook_url.blank?
    if evolution_whatsapp_inbox?(inbox) && (payload[:event] || payload['event']).to_s == 'message_updated'
      return
    end

    transformed_payload = transform_payload_for_api_inbox(payload, inbox)
    WebhookJob.perform_later(inbox.channel.webhook_url, transformed_payload, :api_inbox_webhook)
  end

  def deliver_webhook_payloads(payload, inbox)
    deliver_account_webhooks(payload, inbox.account)
    deliver_api_inbox_webhooks(payload, inbox)
  end

  def transform_payload_for_api_inbox(payload, inbox)
    return payload unless evolution_whatsapp_inbox?(inbox)
    event_name = (payload[:event] || payload['event']).to_s
    return payload unless event_name == 'message_created'

    base_url = env_for('EVOLUTION_CHATWOOT_URL', ENV.fetch('FRONTEND_URL', '')).to_s
    return payload if base_url.blank?

    rewrite_attachments_array!(payload[:attachments] || payload['attachments'], base_url)

    conversation = payload[:conversation] || payload['conversation']
    messages = conversation.is_a?(Hash) ? (conversation[:messages] || conversation['messages']) : nil
    if messages.is_a?(Array)
      messages.each do |message|
        next unless message.is_a?(Hash)

        rewrite_attachments_array!(message[:attachments] || message['attachments'], base_url)
      end
    end

    payload
  end

  def rewrite_attachments_array!(attachments, base_url)
    return unless attachments.is_a?(Array)

    attachments.each do |attachment|
      next unless attachment.is_a?(Hash)

      attachment[:data_url] = rewrite_localhost_url(attachment[:data_url], base_url) if attachment[:data_url].present?
      attachment['data_url'] = rewrite_localhost_url(attachment['data_url'], base_url) if attachment['data_url'].present?
      attachment[:thumb_url] = rewrite_localhost_url(attachment[:thumb_url], base_url) if attachment[:thumb_url].present?
      attachment['thumb_url'] = rewrite_localhost_url(attachment['thumb_url'], base_url) if attachment['thumb_url'].present?

      # Evolution compatibility: some flows expect mediaUrl/base64 keys.
      normalized_media_url = attachment[:data_url] || attachment['data_url']
      attachment[:mediaUrl] = normalized_media_url if normalized_media_url.present?
      attachment['mediaUrl'] = normalized_media_url if normalized_media_url.present?
    end
  end

  def evolution_whatsapp_inbox?(inbox)
    return false unless inbox.channel_type == 'Channel::Api'

    inbox.channel.additional_attributes&.with_indifferent_access&.[](:provider) == 'whatsapp_evo'
  end

  def rewrite_localhost_url(url, base_url)
    uri = URI.parse(url)
    return url unless %w[http https].include?(uri.scheme)
    return url unless %w[localhost 127.0.0.1 0.0.0.0].include?(uri.host)

    target = URI.parse(base_url)
    uri.scheme = target.scheme
    uri.host = target.host
    uri.port = target.port
    uri.to_s
  rescue URI::InvalidURIError
    url
  end

  def env_for(base_key, fallback = '')
    env_key = "#{base_key}_#{Rails.env.upcase}"
    ENV.fetch(env_key, ENV.fetch(base_key, fallback))
  end
end
