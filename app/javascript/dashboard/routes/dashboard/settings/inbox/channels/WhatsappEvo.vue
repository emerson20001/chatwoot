<script>
import { mapGetters } from 'vuex';
import { useVuelidate } from '@vuelidate/core';
import { useAlert } from 'dashboard/composables';
import { required } from '@vuelidate/validators';
import router from '../../../../index';
import PageHeader from '../../SettingsSubPageHeader.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';

export default {
  components: {
    PageHeader,
    NextButton,
  },
  setup() {
    return { v$: useVuelidate() };
  },
  data() {
    return {
      channelName: '',
    };
  },
  computed: {
    ...mapGetters({
      uiFlags: 'inboxes/getUIFlags',
    }),
  },
  validations: {
    channelName: { required },
  },
  methods: {
    async createChannel() {
      this.v$.$touch();
      if (this.v$.$invalid) {
        return;
      }

      try {
        const apiChannel = await this.$store.dispatch('inboxes/createChannel', {
          name: this.channelName?.trim(),
          channel: {
            type: 'api',
            additional_attributes: {
              provider: 'whatsapp_evo',
            },
          },
        });

        router.replace({
          name: 'settings_inboxes_add_agents',
          params: {
            page: 'new',
            inbox_id: apiChannel.id,
          },
        });
      } catch (error) {
        useAlert(error.message || 'Unable to create WhatsApp Evo channel');
      }
    },
  },
};
</script>

<template>
  <div class="h-full w-full p-6 col-span-6">
    <PageHeader
      header-title="WhatsApp Evo"
      header-content="Create an inbox and automatically provision the Evolution API instance and Chatwoot integration."
    />
    <form class="flex flex-wrap flex-col mx-0" @submit.prevent="createChannel()">
      <div class="flex-shrink-0 flex-grow-0">
        <label :class="{ error: v$.channelName.$error }">
          Channel Name
          <input
            v-model="channelName"
            type="text"
            placeholder="Please enter a channel name"
            @blur="v$.channelName.$touch"
          />
          <span v-if="v$.channelName.$error" class="message">
            This field is required
          </span>
        </label>
      </div>

      <div class="w-full mt-4">
        <NextButton
          :is-loading="uiFlags.isCreating"
          type="submit"
          solid
          blue
          label="Create WhatsApp Evo Channel"
        />
      </div>
    </form>
  </div>
</template>
