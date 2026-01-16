const getFavicons = () => document.querySelectorAll('.favicon');

const swapFaviconHref = (favicon, target) => {
  if (target) {
    favicon.href = target;
    return;
  }

  // Fallback to legacy behavior when dataset values are missing
  const size = favicon.sizes && favicon.sizes[0];
  if (size) {
    favicon.href = `/favicon-${size}.png`;
  }
};

export const showBadgeOnFavicon = () => {
  const favicons = getFavicons();

  favicons.forEach(favicon => {
    const defaultHref = favicon.dataset.defaultFavicon || favicon.href;
    favicon.dataset.defaultFavicon = defaultHref;
    const badgeHref = favicon.dataset.badgeFavicon;
    if (badgeHref) {
      favicon.href = badgeHref;
    } else {
      const size = favicon.sizes && favicon.sizes[0];
      if (size) {
        favicon.href = `/favicon-badge-${size}.png`;
      }
    }
  });
};

export const initFaviconSwitcher = () => {
  const favicons = getFavicons();

  document.addEventListener('visibilitychange', () => {
    if (document.visibilityState === 'visible') {
      favicons.forEach(favicon => {
        const originalHref = favicon.dataset.defaultFavicon;
        swapFaviconHref(favicon, originalHref);
      });
    }
  });
};
