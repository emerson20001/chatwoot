<script setup>
import { computed, onMounted, onUnmounted, ref, watchEffect } from 'vue';
import { useRouter } from 'vue-router';
import { useRoute } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useAccount } from 'dashboard/composables/useAccount';

const router = useRouter();
const route = useRoute();
const { t } = useI18n();
const { currentAccount, accountScopedRoute } = useAccount();
const iframeRef = ref(null);

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

const wordpressBlogContext = computed(() => {
  const blog = currentAccount.value?.settings?.wordpress_blog;
  if (!blog || typeof blog !== 'object') {
    return {};
  }

  const blogId = Number.parseInt(blog.blog_id, 10);

  return {
    blog_id: Number.isNaN(blogId) ? null : blogId,
    domain: blog.domain?.toString().trim() || '',
    name: blog.name?.toString().trim() || '',
    slug: blog.slug?.toString().trim() || '',
  };
});

const sendWordpressBlogContext = () => {
  const frame = iframeRef.value;
  if (!frame?.contentWindow) {
    return;
  }

  frame.contentWindow.postMessage(
    JSON.stringify({
      event: 'chatwoot:wordpress-blog-context',
      data: wordpressBlogContext.value,
    }),
    '*'
  );
};

const onIframeLoad = () => {
  sendWordpressBlogContext();
};

const handleContextRequest = event => {
  if (event.data !== 'chatwoot-custom-menu:fetch-wordpress-blog-context') {
    return;
  }

  sendWordpressBlogContext();
};

onMounted(() => {
  window.addEventListener('message', handleContextRequest);
});

onUnmounted(() => {
  window.removeEventListener('message', handleContextRequest);
});

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
      ref="iframeRef"
      :src="selectedMenu.link"
      :title="iframeTitle"
      class="w-full h-full border-0"
      @load="onIframeLoad"
    />
  </section>
</template>
