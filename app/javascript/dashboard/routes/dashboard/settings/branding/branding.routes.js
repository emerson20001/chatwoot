import { frontendURL } from '../../../../helper/URLHelper';
import SettingsWrapper from '../SettingsWrapper.vue';
import BrandingSettings from './BrandingSettings.vue';

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/branding'),
      meta: {
        permissions: ['administrator'],
      },
      component: SettingsWrapper,
      children: [
        {
          path: '',
          name: 'branding_settings_index',
          component: BrandingSettings,
          meta: {
            permissions: ['administrator'],
          },
        },
      ],
    },
  ],
};
