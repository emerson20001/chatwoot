/* global axios */
import ApiClient from './ApiClient';

class AssignableAgents extends ApiClient {
  constructor() {
    super('assignable_agents', { accountScoped: true });
  }

  get(inboxIds, teamId = null) {
    return axios.get(this.url, {
      params: { inbox_ids: inboxIds, ...(teamId ? { team_id: teamId } : {}) },
    });
  }
}

export default new AssignableAgents();
