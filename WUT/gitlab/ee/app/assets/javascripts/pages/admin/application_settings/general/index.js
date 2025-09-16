import '~/pages/admin/application_settings/general/index';
import { initWorkspacesAgentAvailabilityApp } from 'ee/workspaces/admin_settings/init_admin_settings_app';
import { initPrivateProfileRestrictions } from 'ee/admin/application_settings/user_restrictions';
import initAddLicenseApp from 'ee/admin/application_settings/general/add_license';
import { initScimTokenApp } from 'ee/saml_sso';
import { initMaintenanceModeSettings } from 'ee/maintenance_mode_settings';
import { initServicePingSettingsClickTracking } from 'ee/registration_features_discovery_message';
import { initInputCopyToggleVisibility } from '~/vue_shared/components/input_copy_toggle_visibility';
import initAllowedIntegrations from './integrations_settings';

initMaintenanceModeSettings();
initServicePingSettingsClickTracking();
initAddLicenseApp();
initScimTokenApp();
initPrivateProfileRestrictions();
initInputCopyToggleVisibility();
initAllowedIntegrations();
initWorkspacesAgentAvailabilityApp();
