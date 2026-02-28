<script>
import { mapGetters } from 'vuex';
import router from '../../../../index';
import { useAlert } from 'dashboard/composables';
import { useVuelidate } from '@vuelidate/core';

import Spinner from 'shared/components/Spinner.vue';
import PageHeader from '../../SettingsSubPageHeader.vue';
import AgentSelector from '../AgentSelector.vue';

export default {
  components: {
    Spinner,
    PageHeader,
    AgentSelector,
  },
  validations: {
    selectedAgents: {
      isEmpty() {
        return !!this.selectedAgents.length;
      },
    },
  },
  setup() {
    return { v$: useVuelidate() };
  },
  data() {
    return {
      selectedAgents: [],
      isCreating: false,
      allowInboxBypass: false,
    };
  },

  computed: {
    ...mapGetters({
      agentList: 'agents/getAgents',
      uiFlags: 'teamMembers/getUIFlags',
    }),

    teamId() {
      return this.$route.params.teamId;
    },
    headerTitle() {
      return this.$t('TEAMS_SETTINGS.EDIT_FLOW.AGENTS.TITLE', {
        teamName: this.currentTeam.name,
      });
    },
    currentTeam() {
      return this.$store.getters['teams/getTeam'](this.teamId);
    },
    teamMembers() {
      return this.$store.getters['teamMembers/getTeamMembers'](this.teamId);
    },
    showAgentsList() {
      const { id } = this.currentTeam;
      return id && !this.uiFlags.isFetching;
    },
  },

  async mounted() {
    const { teamId } = this.$route.params;
    this.$store.dispatch('agents/get');
    try {
      await this.$store.dispatch('teamMembers/get', {
        teamId,
      });
      const members = this.teamMembers.map(item => item.id);
      this.updateSelectedAgents(members);
      this.allowInboxBypass = this.currentTeam.allow_inbox_bypass ?? false;
    } catch {
      this.updateSelectedAgents([]);
    }
  },

  methods: {
    updateSelectedAgents(newAgentList) {
      this.v$.selectedAgents.$touch();
      this.selectedAgents = [...newAgentList];
    },
    async addAgents() {
      this.isCreating = true;
      const { teamId, selectedAgents } = this;

      try {
        await this.$store.dispatch('teams/update', {
          id: teamId,
          allow_inbox_bypass: this.allowInboxBypass,
        });
        await this.$store.dispatch('teamMembers/update', {
          teamId,
          agentsList: selectedAgents,
        });
        router.replace({
          name: 'settings_teams_edit_finish',
          params: {
            page: 'edit',
            teamId,
          },
        });
        this.$store.dispatch('teams/get');
      } catch (error) {
        useAlert(error.message);
      }
      this.isCreating = false;
    },
  },
};
</script>

<template>
  <div class="h-full w-full p-8 col-span-6">
    <form
      class="flex flex-wrap mx-0 overflow-x-auto"
      @submit.prevent="addAgents"
    >
      <div class="w-full">
        <PageHeader
          :header-title="headerTitle"
          :header-content="$t('TEAMS_SETTINGS.EDIT_FLOW.AGENTS.DESC')"
        />
      </div>

      <div class="w-full mb-4">
        <label class="flex items-center gap-2 cursor-pointer">
          <input
            id="allow-inbox-bypass"
            v-model="allowInboxBypass"
            type="checkbox"
            class="size-4 rounded border-slate-300 text-woot-500 dark:border-slate-600"
          />
          <span class="text-sm text-slate-700 dark:text-slate-300">
            {{ $t('TEAMS_SETTINGS.AGENTS.ALLOW_INBOX_BYPASS.LABEL') }}
          </span>
        </label>
        <p class="mt-1 text-xs text-slate-500 dark:text-slate-400 pl-6">
          {{ $t('TEAMS_SETTINGS.AGENTS.ALLOW_INBOX_BYPASS.DESC') }}
        </p>
      </div>

      <div class="w-full">
        <div v-if="v$.selectedAgents.$error">
          <p class="error-message pb-2">
            {{ $t('TEAMS_SETTINGS.ADD.AGENT_VALIDATION_ERROR') }}
          </p>
        </div>
        <AgentSelector
          v-if="showAgentsList"
          :agent-list="agentList"
          :selected-agents="selectedAgents"
          :update-selected-agents="updateSelectedAgents"
          :is-working="isCreating"
          :submit-button-text="
            $t('TEAMS_SETTINGS.EDIT_FLOW.AGENTS.BUTTON_TEXT')
          "
        />
        <Spinner v-else />
      </div>
    </form>
  </div>
</template>
