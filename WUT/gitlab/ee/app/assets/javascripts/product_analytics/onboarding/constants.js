export const INSTALL_NPM_PACKAGE = `yarn add @gitlab/application-sdk-browser

OR

npm install @gitlab/application-sdk-browser`;

export const IMPORT_NPM_PACKAGE = `// import as an ES module
import { glClientSDK } from '@gitlab/application-sdk-browser';

OR

// import as a CommonJS module
const { glClientSDK } = require('@gitlab/application-sdk-browser');
`;

export const INIT_TRACKING = `this.glClient = glClientSDK({ appId: '%{appId}', host: '%{host}' });`;

export const HTML_SCRIPT_SETUP = `<script src="https://unpkg.com/@gitlab/application-sdk-browser/dist/gl-sdk.min.js"></script>
<script>window.glClient = window.glSDK.glClientSDK({
    appId: '%{appId}',
    host: '%{host}',
});
// Tracks the current page view
window.glClient.page();
</script>`;

export const SHORT_POLLING_INTERVAL = 1000;

export const LONG_POLLING_INTERVAL = 2500;

export const STATE_CREATE_INSTANCE = 'CREATE_INSTANCE';

export const STATE_LOADING_INSTANCE = 'LOADING_INSTANCE';

export const STATE_WAITING_FOR_EVENTS = 'WAITING_FOR_EVENTS';

export const STATE_COMPLETE = 'COMPLETE';
