class Conversations::PermissionFilterService
  attr_reader :conversations, :user, :account

  def initialize(conversations, user, account)
    @conversations = conversations
    @user = user
    @account = account
  end

  def perform
    return conversations if user_role == 'administrator'

    accessible_conversations
  end

  private

  def accessible_conversations
    inbox_scope = conversations.where(inbox: user.inboxes.where(account_id: account.id))

    team_ids = user.teams.where(account_id: account.id, allow_inbox_bypass: true).pluck(:id)
    return inbox_scope if team_ids.empty?

    inbox_scope.or(conversations.where(team_id: team_ids))
  end

  def account_user
    AccountUser.find_by(account_id: account.id, user_id: user.id)
  end

  def user_role
    account_user&.role
  end
end

Conversations::PermissionFilterService.prepend_mod_with('Conversations::PermissionFilterService')
