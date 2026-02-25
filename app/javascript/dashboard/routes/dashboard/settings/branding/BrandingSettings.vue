<script setup>
import { ref, reactive, onMounted, computed } from 'vue';
import axios from 'axios';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useAccount } from 'dashboard/composables/useAccount';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import SectionLayout from '../account/components/SectionLayout.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';

const loading = ref(true);
const saving = ref(false);
const domainLabel = ref('');
const configs = reactive({
  logo: '',
  logo_dark: '',
  logo_thumbnail: '',
});
const urls = reactive({
  logo: '',
  logo_dark: '',
  logo_thumbnail: '',
});
const files = reactive({
  logo: null,
  logo_dark: null,
  logo_thumbnail: null,
});
const removeFlags = reactive({
  logo: false,
  logo_dark: false,
  logo_thumbnail: false,
});

const { t } = useI18n();

const fieldDefinitions = [
  {
    key: 'logo',
    titleKey: 'BRANDING_SETTINGS.FIELDS.LOGO.TITLE',
    helperKey: 'BRANDING_SETTINGS.FIELDS.LOGO.HELPER',
  },
  {
    key: 'logo_dark',
    titleKey: 'BRANDING_SETTINGS.FIELDS.LOGO_DARK.TITLE',
    helperKey: 'BRANDING_SETTINGS.FIELDS.LOGO_DARK.HELPER',
  },
  {
    key: 'logo_thumbnail',
    titleKey: 'BRANDING_SETTINGS.FIELDS.LOGO_THUMBNAIL.TITLE',
    helperKey: 'BRANDING_SETTINGS.FIELDS.LOGO_THUMBNAIL.HELPER',
  },
];

const fields = computed(() =>
  fieldDefinitions.map(field => ({
    ...field,
    title: t(field.titleKey),
    helper: t(field.helperKey),
  }))
);

const hasChanges = computed(() => {
  return fieldDefinitions.some(
    field =>
      files[field.key] ||
      removeFlags[field.key] ||
      (urls[field.key] && urls[field.key].trim() !== '')
  );
});

const http = window.axios || axios;
const { accountId, currentAccount } = useAccount();

const resolveDomainLabel = payload => {
  const browserHost =
    typeof window === 'undefined' ? '' : window.location.hostname;

  return (
    payload?.domain || currentAccount.value?.domain || browserHost || 'default'
  );
};

const requestHeaders = () => {
  const token = document
    .querySelector('meta[name="csrf-token"]')
    ?.getAttribute('content');

  return {
    'X-CSRF-Token': token,
    Accept: 'application/json',
  };
};

const fetchConfigs = async () => {
  loading.value = true;
  try {
    const response = await http.get('/admin/branding.json', {
      headers: requestHeaders(),
      params: { account_id: accountId.value },
    });
    const responseConfigs = response.data?.configs || {};
    domainLabel.value = resolveDomainLabel(response.data);
    fieldDefinitions.forEach(field => {
      configs[field.key] = responseConfigs[field.key] || '';
      urls[field.key] = '';
      files[field.key] = null;
      removeFlags[field.key] = false;
    });
  } catch (error) {
    useAlert(t('BRANDING_SETTINGS.ALERTS.LOAD_ERROR'));
  } finally {
    loading.value = false;
  }
};

const handleFileChange = (event, key) => {
  const [file] = event.target.files;
  files[key] = file || null;
  if (file) {
    removeFlags[key] = false;
  }
};

const markForRemoval = key => {
  removeFlags[key] = true;
  files[key] = null;
  urls[key] = '';
  configs[key] = '';
};

const submit = async () => {
  if (!hasChanges.value) {
    useAlert(t('BRANDING_SETTINGS.ALERTS.NO_CHANGES'));
    return;
  }

  saving.value = true;
  const formData = new FormData();

  fieldDefinitions.forEach(field => {
    const key = field.key;
    if (removeFlags[key]) {
      formData.append(`branding[${key}][remove]`, 'true');
    } else if (files[key]) {
      formData.append(`branding[${key}][file]`, files[key]);
    } else if (urls[key]) {
      formData.append(`branding[${key}][url]`, urls[key]);
    }
  });
  formData.append('account_id', accountId.value);

  try {
    await http.put('/admin/branding.json', formData, {
      headers: requestHeaders(),
      params: { account_id: accountId.value },
    });
    useAlert(t('BRANDING_SETTINGS.ALERTS.SAVE_SUCCESS'));
    await fetchConfigs();
  } catch (error) {
    useAlert(t('BRANDING_SETTINGS.ALERTS.SAVE_ERROR'));
  } finally {
    saving.value = false;
  }
};

onMounted(fetchConfigs);
</script>

<template>
  <div class="flex flex-col max-w-3xl w-full">
    <BaseSettingsHeader :title="t('BRANDING_SETTINGS.HEADER')" />
    <p class="text-sm text-slate-600 mt-2">
      {{ t('BRANDING_SETTINGS.DOMAIN_LABEL') }}
      <span class="font-semibold text-slate-900">{{ domainLabel }}</span>
    </p>
    <div v-if="loading" class="text-sm text-slate-600 mt-6">
      {{ t('BRANDING_SETTINGS.LOADING') }}
    </div>
    <form v-else class="mt-6 space-y-6" @submit.prevent="submit">
      <SectionLayout
        v-for="field in fields"
        :key="field.key"
        :title="field.title"
        :description="field.helper"
      >
        <div class="space-y-3">
          <div v-if="configs[field.key]" class="flex items-center gap-4">
            <img
              :src="configs[field.key]"
              :alt="field.title"
              class="h-16 w-auto rounded border border-slate-200 bg-white p-1"
            />
            <span class="text-xs text-slate-500 break-all">
              {{ configs[field.key] }}
            </span>
          </div>
          <label class="block text-sm font-medium text-slate-700">
            {{ t('BRANDING_SETTINGS.UPLOAD_LABEL') }}
            <input
              type="file"
              class="mt-1 block w-full text-sm text-slate-600"
              @change="event => handleFileChange(event, field.key)"
            />
          </label>
          <label class="block text-sm font-medium text-slate-700">
            {{ t('BRANDING_SETTINGS.CUSTOM_URL_LABEL') }}
            <input
              v-model="urls[field.key]"
              type="text"
              class="cw-input w-full mt-1"
              :placeholder="t('BRANDING_SETTINGS.CUSTOM_URL_PLACEHOLDER')"
              @input="removeFlags[field.key] = false"
            />
          </label>
          <div class="flex justify-end">
            <button
              v-if="configs[field.key]"
              type="button"
              class="text-sm text-red-600 hover:text-red-700 font-medium"
              @click="markForRemoval(field.key)"
            >
              {{ t('BRANDING_SETTINGS.REMOVE_BUTTON') }}
            </button>
          </div>
        </div>
      </SectionLayout>
      <div class="flex justify-end">
        <NextButton type="submit" :is-loading="saving">
          {{ t('BRANDING_SETTINGS.SAVE_BUTTON') }}
        </NextButton>
      </div>
    </form>
  </div>
</template>
