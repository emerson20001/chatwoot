<script setup>
import { computed, onMounted, onUnmounted, ref, watch, watchEffect } from 'vue';
import { useRouter } from 'vue-router';
import { useRoute } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useAccount } from 'dashboard/composables/useAccount';

const router = useRouter();
const route = useRoute();
const { t } = useI18n();
const { currentAccount, accountScopedRoute } = useAccount();
const iframeRef = ref(null);
const N8N_READY_COMMAND = 'n8nSigninReadyForInviteeAutoLogin';
const N8N_AUTO_LOGIN_COMMAND = 'n8nAutoLoginByInviteeId';
const N8N_ROUTE_CHANGED_COMMAND = 'n8nRouteChanged';
const N8N_FORCE_LOGOUT_COMMAND = 'n8nForceLogoutToSignin';
const N8N_AUTH_PATHS = new Set(['/signin', '/signup', '/mfa']);
const isIframeVisible = ref(true);
const hasSentN8nAutoLogin = ref(false);
const n8nInitialLoadingUntil = ref(0);
let iframeRevealTimeout = null;

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

const iframeSessionKey = computed(() => {
  const accountId = currentAccount.value?.id;
  const menu = selectedMenu.value;
  if (!accountId || !menu?.link || !menu?.label) {
    return '';
  }

  return `chatwoot-custom-menu:last-url:${accountId}:${menu.label}:${menu.link}`;
});

const inviteeCacheToken = computed(() => wordpressBlogContext.value.invitee_id || 'none');

const iframeRenderKey = computed(() => {
  const accountId = currentAccount.value?.id || 'no-account';
  const menu = selectedMenu.value;
  const menuKey = menu ? `${menu.label}:${menu.link}` : 'no-menu';

  return `iframe:${accountId}:${menuKey}:${inviteeCacheToken.value}`;
});

const normalizedMenuUrl = computed(() => {
  const selectedLink = selectedMenu.value?.link;
  if (!selectedLink) {
    return null;
  }

  try {
    const url = new URL(selectedLink, window.location.origin);

    // Keep n8n iframe on the same hostname as Chatwoot to avoid session split
    // between localhost/IP/domain variants.
    if (url.port === '5678' && url.hostname !== window.location.hostname) {
      url.hostname = window.location.hostname;
    }

    if (url.pathname === '/signin') {
      url.pathname = '/';
      url.search = '';
      url.hash = '';
    }

    return url;
  } catch {
    return null;
  }
});

const iframeSrc = computed(() => {
  const appendCacheBuster = rawUrl => {
    if (!isN8nIframe.value) {
      return rawUrl;
    }

    try {
      const url = new URL(rawUrl, window.location.origin);
      url.searchParams.set('_cw_invitee', inviteeCacheToken.value);
      return url.toString();
    } catch {
      return rawUrl;
    }
  };

  if (iframeSessionKey.value) {
    const storedUrl = window.sessionStorage.getItem(iframeSessionKey.value);
    if (storedUrl) {
      try {
        const parsedStoredUrl = new URL(storedUrl);
        if (
          normalizedMenuUrl.value &&
          parsedStoredUrl.origin === normalizedMenuUrl.value.origin &&
          !N8N_AUTH_PATHS.has(parsedStoredUrl.pathname)
        ) {
          return appendCacheBuster(parsedStoredUrl.toString());
        } else if (N8N_AUTH_PATHS.has(parsedStoredUrl.pathname)) {
          window.sessionStorage.removeItem(iframeSessionKey.value);
        }
      } catch {
        // Fallback to menu URL below
      }
    }
  }

  if (normalizedMenuUrl.value) {
    return appendCacheBuster(normalizedMenuUrl.value.toString());
  }

  return selectedMenu.value?.link || '';
});

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
    invitee_id: blog.invitee_id?.toString().trim() || '',
  };
});

const iframePostMessageTarget = computed(() => {
  return normalizedMenuUrl.value?.origin || '*';
});

const isN8nIframe = computed(() => normalizedMenuUrl.value?.port === '5678');
const n8nLogoSrc = computed(() =>
  isN8nIframe.value && normalizedMenuUrl.value
    ? `${normalizedMenuUrl.value.origin}/static/n8n-logo.png`
    : ''
);

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
    iframePostMessageTarget.value
  );
};

const sendN8nAutoLoginContext = () => {
  const frame = iframeRef.value;
  const inviteeId = wordpressBlogContext.value.invitee_id;
  if (!frame?.contentWindow || !inviteeId) {
    return false;
  }

  const payload = {
    command: N8N_AUTO_LOGIN_COMMAND,
    inviteeId,
    wordpressBlog: wordpressBlogContext.value,
  };

  frame.contentWindow.postMessage(
    JSON.stringify(payload),
    iframePostMessageTarget.value
  );

  return true;
};

const sendN8nForceLogoutContext = () => {
  const frame = iframeRef.value;
  if (!frame?.contentWindow) {
    return false;
  }

  frame.contentWindow.postMessage(
    JSON.stringify({
      command: N8N_FORCE_LOGOUT_COMMAND,
    }),
    iframePostMessageTarget.value
  );

  return true;
};

const shouldHideN8nIframeForUrl = parsedUrl =>
  parsedUrl.pathname === '/signup' || parsedUrl.pathname === '/mfa';

const persistIframeSessionUrl = rawUrl => {
  if (!iframeSessionKey.value || !rawUrl) {
    return;
  }

  try {
    const parsedUrl = new URL(rawUrl, window.location.origin);
    if (
      normalizedMenuUrl.value &&
      parsedUrl.origin === normalizedMenuUrl.value.origin &&
      !N8N_AUTH_PATHS.has(parsedUrl.pathname)
    ) {
      window.sessionStorage.setItem(iframeSessionKey.value, parsedUrl.toString());
    }
  } catch {
    // Ignore invalid URL payloads
  }
};

const onIframeLoad = () => {
  persistIframeSessionUrl(iframeSrc.value);

  if (!isN8nIframe.value) {
    isIframeVisible.value = true;
  }

  if (
    isN8nIframe.value &&
    !wordpressBlogContext.value.invitee_id &&
    !hasSentN8nAutoLogin.value
  ) {
    hasSentN8nAutoLogin.value = sendN8nForceLogoutContext();
  }

  sendWordpressBlogContext();
};

const parseMessageData = data => {
  if (typeof data === 'string') {
    try {
      return JSON.parse(data);
    } catch {
      return data;
    }
  }

  return data;
};

const handleContextRequest = event => {
  const parsedData = parseMessageData(event.data);

  if (parsedData === 'chatwoot-custom-menu:fetch-wordpress-blog-context') {
    sendWordpressBlogContext();
    return;
  }

  if (parsedData?.command === N8N_READY_COMMAND) {
    const inviteeId = wordpressBlogContext.value.invitee_id;
    hasSentN8nAutoLogin.value = inviteeId
      ? sendN8nAutoLoginContext()
      : sendN8nForceLogoutContext();
    return;
  }

  if (
    parsedData?.command === N8N_ROUTE_CHANGED_COMMAND &&
    typeof parsedData?.url === 'string' &&
    iframeSessionKey.value
  ) {
    try {
      const parsedUrl = new URL(parsedData.url);
      if (
        normalizedMenuUrl.value &&
        parsedUrl.origin === normalizedMenuUrl.value.origin
      ) {
        // Hide n8n iframe while it is in auth screens to avoid flashing /signin.
        if (Date.now() < n8nInitialLoadingUntil.value) {
          isIframeVisible.value = false;
        } else {
          isIframeVisible.value = !shouldHideN8nIframeForUrl(parsedUrl);
        }

        persistIframeSessionUrl(parsedUrl.toString());
      }
    } catch {
      // Ignore invalid URL payloads
    }
  }
};

onMounted(() => {
  window.addEventListener('message', handleContextRequest);
});

onUnmounted(() => {
  window.removeEventListener('message', handleContextRequest);
  if (iframeRevealTimeout) {
    window.clearTimeout(iframeRevealTimeout);
    iframeRevealTimeout = null;
  }
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

watchEffect(() => {
  if (!selectedMenu.value) {
    return;
  }

  // Reset one-shot auto-login whenever user switches custom menu.
  hasSentN8nAutoLogin.value = false;

  if (iframeRevealTimeout) {
    window.clearTimeout(iframeRevealTimeout);
    iframeRevealTimeout = null;
  }

  if (isN8nIframe.value) {
    // Start hidden for n8n and reveal when route changes away from auth pages.
    isIframeVisible.value = false;
    n8nInitialLoadingUntil.value = Date.now() + 2000;
    iframeRevealTimeout = window.setTimeout(() => {
      isIframeVisible.value = true;
      iframeRevealTimeout = null;
    }, 2000);
    return;
  }

  isIframeVisible.value = true;
});

watch(inviteeCacheToken, () => {
  hasSentN8nAutoLogin.value = false;
});
</script>

<template>
  <section class="relative w-full h-full overflow-hidden">
    <div
      v-if="selectedMenu && isN8nIframe && !isIframeVisible"
      class="absolute inset-0 z-10 flex flex-col items-center justify-center gap-3 bg-white"
    >
      <img
        v-if="n8nLogoSrc"
        :src="n8nLogoSrc"
        alt="n8n"
        class="w-16 h-16 object-contain"
      />
      <div class="text-sm font-medium text-slate-600">Carregando n8n...</div>
    </div>

    <iframe
      v-if="selectedMenu"
      :key="iframeRenderKey"
      ref="iframeRef"
      :src="iframeSrc"
      :title="iframeTitle"
      :class="[
        'w-full h-full border-0 transition-opacity duration-150',
        isIframeVisible ? 'opacity-100' : 'opacity-0',
      ]"
      @load="onIframeLoad"
    />
  </section>
</template>
