import AssignableAgentsAPI from '../../api/assignableAgents';

const NO_TEAM_KEY = 'no-team';
const NO_INBOX_KEY = 'no-inbox';

const normalizeInboxIds = inboxIds => {
  if (inboxIds === undefined || inboxIds === null || inboxIds === '') {
    return NO_INBOX_KEY;
  }
  if (Array.isArray(inboxIds)) {
    if (!inboxIds.length) {
      return NO_INBOX_KEY;
    }
    return inboxIds.join(',');
  }
  return `${inboxIds}`;
};

const buildRecordKey = ({ inboxIds, teamId = null }) => {
  const normalizedInboxIds = normalizeInboxIds(inboxIds);
  const normalizedTeamId = teamId || NO_TEAM_KEY;
  return `${normalizedInboxIds}::${normalizedTeamId}`;
};

const state = {
  records: {},
  uiFlags: {
    isFetching: false,
  },
};

export const types = {
  SET_INBOX_ASSIGNABLE_AGENTS_UI_FLAG: 'SET_INBOX_ASSIGNABLE_AGENTS_UI_FLAG',
  SET_INBOX_ASSIGNABLE_AGENTS: 'SET_INBOX_ASSIGNABLE_AGENTS',
};

export const getters = {
  getAssignableAgents: $state => input => {
    const inboxIds =
      typeof input === 'object' && input !== null ? input.inboxIds : input;
    const teamId =
      typeof input === 'object' && input !== null ? input.teamId || null : null;
    const key = buildRecordKey({ inboxIds, teamId });
    const teamOnlyKey = buildRecordKey({ inboxIds: null, teamId });
    const fallbackKey = buildRecordKey({ inboxIds, teamId: null });
    const allAgents =
      $state.records[key] ||
      $state.records[teamOnlyKey] ||
      $state.records[fallbackKey] ||
      [];
    const verifiedAgents = allAgents.filter(record => record.confirmed);
    return verifiedAgents;
  },
  getUIFlags($state) {
    return $state.uiFlags;
  },
};

export const actions = {
  async fetch({ commit }, payload) {
    commit(types.SET_INBOX_ASSIGNABLE_AGENTS_UI_FLAG, { isFetching: true });
    const inboxIds = Array.isArray(payload) ? payload : payload.inboxIds;
    const teamId = Array.isArray(payload) ? null : payload.teamId || null;
    const recordKey = buildRecordKey({ inboxIds, teamId });
    try {
      const {
        data: { payload: agents },
      } = await AssignableAgentsAPI.get(inboxIds, teamId);
      commit(types.SET_INBOX_ASSIGNABLE_AGENTS, {
        inboxId: recordKey,
        members: agents,
      });
    } catch (error) {
      throw new Error(error);
    } finally {
      commit(types.SET_INBOX_ASSIGNABLE_AGENTS_UI_FLAG, { isFetching: false });
    }
  },
};

export const mutations = {
  [types.SET_INBOX_ASSIGNABLE_AGENTS_UI_FLAG]($state, data) {
    $state.uiFlags = {
      ...$state.uiFlags,
      ...data,
    };
  },
  [types.SET_INBOX_ASSIGNABLE_AGENTS]: ($state, { inboxId, members }) => {
    $state.records = {
      ...$state.records,
      [inboxId]: members,
    };
  },
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
