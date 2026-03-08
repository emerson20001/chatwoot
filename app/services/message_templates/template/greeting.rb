class MessageTemplates::Template::Greeting
  pattr_initialize [:conversation!]

  def perform
    conversation.with_lock do
      return if greeting_already_sent?
      return unless greeting_eligible?

      conversation.messages.create!(greeting_message_params)
    end
  rescue StandardError => e
    ChatwootExceptionTracker.new(e, account: conversation.account).capture_exception
    true
  end

  private

  delegate :contact, :account, to: :conversation
  delegate :inbox, to: :message

  def greeting_message_params
    content = @conversation.inbox&.greeting_message

    {
      account_id: @conversation.account_id,
      inbox_id: @conversation.inbox_id,
      message_type: :template,
      content: content
    }
  end

  def greeting_already_sent?
    conversation.messages.template.exists?
  end

  def greeting_eligible?
    conversation.messages.outgoing.count.zero? &&
      @conversation.inbox&.greeting_enabled? &&
      @conversation.inbox&.greeting_message.present?
  end
end
