const getCacheBustToken = () => {
  const { appVersion = '', gitSha = '' } = window.globalConfig || {};
  return `${appVersion}-${gitSha}`.replace(/\s+/g, '');
};

const withCacheBust = url => {
  if (!url) return url;
  const separator = url.includes('?') ? '&' : '?';
  return `${url}${separator}v=${encodeURIComponent(getCacheBustToken())}`;
};

export const showBadgeOnFavicon = () => {
  const favicons = document.querySelectorAll('.favicon');

  favicons.forEach(favicon => {
    if (!favicon.dataset.originalHref) {
      favicon.dataset.originalHref = favicon.href;
    }
    const newFileName = `/favicon-badge-${favicon.sizes[[0]]}.png`;
    favicon.href = withCacheBust(newFileName);
  });
};

export const initFaviconSwitcher = () => {
  const favicons = document.querySelectorAll('.favicon');

  favicons.forEach(favicon => {
    if (!favicon.dataset.originalHref) {
      favicon.dataset.originalHref = favicon.href;
    }
  });

  document.addEventListener('visibilitychange', () => {
    if (document.visibilityState === 'visible') {
      favicons.forEach(favicon => {
        favicon.href = withCacheBust(favicon.dataset.originalHref || favicon.href);
      });
    }
  });
};
