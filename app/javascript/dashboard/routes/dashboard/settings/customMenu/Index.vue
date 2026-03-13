<script setup>
import { computed, onMounted, onUnmounted, ref, watch, watchEffect } from 'vue';
import { useRouter } from 'vue-router';
import { useRoute } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useAccount } from 'dashboard/composables/useAccount';
import { useMapGetter } from 'dashboard/composables/store';

const router = useRouter();
const route = useRoute();
const { t } = useI18n();
const { currentAccount, accountScopedRoute } = useAccount();
const currentUserRole = useMapGetter('getCurrentRole');
const currentUser = useMapGetter('getCurrentUser');
const isSuperAdmin = computed(() => currentUser.value?.type === 'SuperAdmin');
const iframeRef = ref(null);
const N8N_READY_COMMAND = 'n8nSigninReadyForInviteeAutoLogin';
const N8N_AUTO_LOGIN_COMMAND = 'n8nAutoLoginByInviteeId';
const N8N_ROUTE_CHANGED_COMMAND = 'n8nRouteChanged';
const N8N_FORCE_LOGOUT_COMMAND = 'n8nForceLogoutToSignin';
const TYPEBOT_READY_COMMAND = 'typebotSigninReadyForTypebotAutoLogin';
const TYPEBOT_AUTO_LOGIN_COMMAND = 'typebotAutoLoginByTypebotId';
const CUSTOM_MENU_CONTEXT_EVENT = 'chatwoot:custom-menu-context';
const CUSTOM_MENU_CONTEXT_REQUEST = 'chatwoot-custom-menu:fetch-context';
const N8N_AUTH_PATHS = new Set(['/signin', '/signup', '/mfa']);
const isIframeVisible = ref(true);
const hasSentN8nAutoLogin = ref(false);
const hasSentTypebotAutoLogin = ref(false);
const n8nInitialLoadingUntil = ref(0);
let iframeRevealTimeout = null;

const normalizedCustomMenus = computed(() => {
  const rawCustomMenus = currentAccount.value?.settings?.custom_menus;

  if (Array.isArray(rawCustomMenus)) {
    return rawCustomMenus;
  }

  if (rawCustomMenus && typeof rawCustomMenus === 'object') {
    return Object.values(rawCustomMenus);
  }

  return [];
});

const customMenus = computed(() =>
  normalizedCustomMenus.value.filter(menu => {
    if (!menu?.label?.trim() || !menu?.link?.trim()) {
      return false;
    }

    if (isSuperAdmin.value) {
      return true;
    }

    if (currentUserRole.value === 'administrator') {
      return menu.visible_for_administrator !== false;
    }

    if (currentUserRole.value === 'agent') {
      return menu.visible_for_agent !== false;
    }

    return false;
  })
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

    const normalizedUrl = url.toString().toLowerCase();
    const isN8nUrl = url.port === '5678' || normalizedUrl.includes('n8n');

    if (isN8nUrl && url.pathname === '/signin') {
      url.pathname = '/';
      url.search = '';
      url.hash = '';
    }

    return url;
  } catch {
    return null;
  }
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
    typebot_id: blog.typebot_id?.toString().trim() || '',
  };
});

const selectedMenuContext = computed(() => {
  const menu = selectedMenu.value || {};
  const valueFor = key => {
    const value = menu?.[key];
    if (value === null || value === undefined) {
      return '';
    }

    return value.toString().trim();
  };

  return {
    label: valueFor('label'),
    link: valueFor('link'),
    token_id: valueFor('token_id'),
    blog_id: valueFor('blog_id'),
    url_blog_id: valueFor('url_blog_id'),
  };
});

const inviteeId = computed(() => selectedMenuContext.value.token_id || '');
const typebotId = computed(() => selectedMenuContext.value.token_id || '');

const inviteeCacheToken = computed(() => inviteeId.value || 'none');
const typebotCacheToken = computed(() => typebotId.value || 'none');

const iframeRenderKey = computed(() => {
  const accountId = currentAccount.value?.id || 'no-account';
  const menu = selectedMenu.value;
  const menuKey = menu ? `${menu.label}:${menu.link}` : 'no-menu';

  return `iframe:${accountId}:${menuKey}:${inviteeCacheToken.value}:${typebotCacheToken.value}`;
});

const iframePostMessageTarget = computed(() => {
  return normalizedMenuUrl.value?.origin || '*';
});

const isN8nIframe = computed(() => {
  const url = normalizedMenuUrl.value;
  if (!url) {
    return false;
  }

  const normalizedUrl = url.toString().toLowerCase();

  // Keep original localhost behavior and also support production/custom n8n URLs.
  return url.port === '5678' || normalizedUrl.includes('n8n');
});
const isTypebotIframe = computed(() => {
  const url = normalizedMenuUrl.value;
  if (!url) {
    return false;
  }

  const normalizedUrl = url.toString().toLowerCase();

  return url.port === '8090' || normalizedUrl.includes('typebot');
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
        }
        if (N8N_AUTH_PATHS.has(parsedStoredUrl.pathname)) {
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

const isIntegrationIframe = computed(
  () => isN8nIframe.value || isTypebotIframe.value
);
const loadingOverlayLabel = computed(() => {
  const menuName = selectedMenu.value?.label?.trim();
  return menuName ? `Carregando ${menuName}...` : 'Carregando...';
});

const buildCustomMenuContextPayload = () => ({
  event: CUSTOM_MENU_CONTEXT_EVENT,
  data: {
    menu: selectedMenuContext.value,
    auth: {
      token_id: selectedMenuContext.value.token_id,
      invitee_id: inviteeId.value,
      typebot_id: typebotId.value,
    },
    wordpressBlog: wordpressBlogContext.value,
  },
});

const sendCustomMenuContext = () => {
  const frame = iframeRef.value;
  if (!frame?.contentWindow) {
    return;
  }

  frame.contentWindow.postMessage(
    JSON.stringify(buildCustomMenuContextPayload()),
    iframePostMessageTarget.value
  );
};

const sendN8nAutoLoginContext = () => {
  const frame = iframeRef.value;
  if (!frame?.contentWindow || !inviteeId.value) {
    return false;
  }

  const payload = {
    command: N8N_AUTO_LOGIN_COMMAND,
    inviteeId: inviteeId.value,
    context: buildCustomMenuContextPayload().data,
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

const sendTypebotAutoLoginContext = () => {
  const frame = iframeRef.value;
  if (!frame?.contentWindow || !typebotId.value) {
    return false;
  }

  frame.contentWindow.postMessage(
    JSON.stringify({
      command: TYPEBOT_AUTO_LOGIN_COMMAND,
      typebotId: typebotId.value,
      context: buildCustomMenuContextPayload().data,
    }),
    iframePostMessageTarget.value
  );

  return true;
};

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
      window.sessionStorage.setItem(
        iframeSessionKey.value,
        parsedUrl.toString()
      );
    }
  } catch {
    // Ignore invalid URL payloads
  }
};

const onIframeLoad = () => {
  persistIframeSessionUrl(iframeSrc.value);

  if (!isIntegrationIframe.value) {
    isIframeVisible.value = true;
  }

  if (isN8nIframe.value && !inviteeId.value && !hasSentN8nAutoLogin.value) {
    hasSentN8nAutoLogin.value = sendN8nForceLogoutContext();
  }

  sendCustomMenuContext();
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

  if (
    parsedData === CUSTOM_MENU_CONTEXT_REQUEST ||
    parsedData === 'chatwoot-custom-menu:fetch-wordpress-blog-context'
  ) {
    sendCustomMenuContext();
    return;
  }

  if (parsedData?.command === N8N_READY_COMMAND) {
    if (hasSentN8nAutoLogin.value) {
      return;
    }

    hasSentN8nAutoLogin.value = inviteeId.value
      ? sendN8nAutoLoginContext()
      : sendN8nForceLogoutContext();
    return;
  }

  if (parsedData?.command === TYPEBOT_READY_COMMAND) {
    if (hasSentTypebotAutoLogin.value) {
      return;
    }

    hasSentTypebotAutoLogin.value = sendTypebotAutoLoginContext();
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
          // After initial loading, keep auth pages visible (e.g. /signin after sign out).
          isIframeVisible.value = true;
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
  hasSentTypebotAutoLogin.value = false;

  if (iframeRevealTimeout) {
    window.clearTimeout(iframeRevealTimeout);
    iframeRevealTimeout = null;
  }

  if (isIntegrationIframe.value) {
    // Start hidden for integrations and reveal after the loading grace period.
    isIframeVisible.value = false;
    n8nInitialLoadingUntil.value = Date.now() + 3000;
    iframeRevealTimeout = window.setTimeout(() => {
      isIframeVisible.value = true;
      iframeRevealTimeout = null;
    }, 3000);
    return;
  }

  isIframeVisible.value = true;
});

watch([inviteeCacheToken, typebotCacheToken], () => {
  hasSentN8nAutoLogin.value = false;
  hasSentTypebotAutoLogin.value = false;
});
</script>

<template>
  <section class="relative w-full h-full overflow-hidden">
    <div
      v-if="selectedMenu && isIntegrationIframe && !isIframeVisible"
      class="absolute inset-0 z-10 flex flex-col items-center justify-center gap-3 bg-white"
    >
      <span
        class="h-12 w-12 rounded-full border-4 border-slate-200 border-t-slate-600 animate-spin"
      />
      <div class="text-sm font-medium text-slate-600">
        {{ loadingOverlayLabel }}
      </div>
    </div>

    <iframe
      v-if="selectedMenu"
      :key="iframeRenderKey"
      ref="iframeRef"
      :src="iframeSrc"
      :title="iframeTitle"
      class="w-full h-full border-0 transition-opacity duration-150"
      :class="[isIframeVisible ? 'opacity-100' : 'opacity-0']"
      @load="onIframeLoad"
    />
  </section>
</template>
