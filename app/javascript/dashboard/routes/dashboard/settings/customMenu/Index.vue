<script setup>
import { computed, watchEffect } from 'vue';
import { useRouter } from 'vue-router';
import { useRoute } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useAccount } from 'dashboard/composables/useAccount';

const router = useRouter();
const route = useRoute();
const { t } = useI18n();
const { currentAccount, accountScopedRoute } = useAccount();

const customMenus = computed(
  () =>
    currentAccount.value?.settings?.custom_menus?.filter(
      menu => menu?.label?.trim() && menu?.link?.trim()
    ) || []
);
const menuIndex = computed(() => Number(route.params.menuIndex || 0));
const selectedMenu = computed(() => customMenus.value[menuIndex.value]);

const iframeTitle = computed(
  () => selectedMenu.value?.label || t('SIDEBAR.CUSTOM_MENU')
);

watchEffect(() => {
  if (!currentAccount.value?.id) {
    return;
  }

  if (selectedMenu.value) {
    return;
  }

  router.replace(accountScopedRoute('settings_home'));
});
</script>

<template>
  <section class="w-full h-full overflow-hidden">
    <iframe
      v-if="selectedMenu"
      :src="selectedMenu.link"
      :title="iframeTitle"
      class="w-full h-full border-0"
    />
  </section>
</template>
