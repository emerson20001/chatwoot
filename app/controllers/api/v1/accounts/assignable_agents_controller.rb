class Api::V1::Accounts::AssignableAgentsController < Api::V1::Accounts::BaseController
  before_action :fetch_inboxes

  def index
    agent_ids = @inboxes.map do |inbox|
      authorize_assignable_agents_access!(inbox)
      inbox.members.pluck(:user_id)
    end
    agent_ids = agent_ids.inject(:&) || []
    agents = Current.account.users.where(id: agent_ids)
    @assignable_agents = (agents + Current.account.administrators + bypass_team_agents).uniq
  end

  private

  def authorize_assignable_agents_access!(inbox)
    return if Current.account_user&.administrator?
    return if Current.user.assigned_inboxes.include?(inbox)
    return if bypass_team_access_for_current_user?

    raise Pundit::NotAuthorizedError
  end

  def bypass_team_access_for_current_user?
    team = Current.account.teams.find_by(id: permitted_params[:team_id])
    return false unless team&.allow_inbox_bypass?

    team.members.exists?(id: Current.user.id)
  end

  def bypass_team_agents
    return [] if permitted_params[:team_id].blank?

    team = Current.account.teams.find_by(id: permitted_params[:team_id])
    return [] unless team&.allow_inbox_bypass?

    team.members.to_a
  end

  def fetch_inboxes
    @inboxes = Current.account.inboxes.find(permitted_params[:inbox_ids])
  end

  def permitted_params
    params.permit(:team_id, inbox_ids: [])
  end
end
