import * as types from './mutation_types';
import { normalizeLicense } from './utils';

export default {
  [types.SET_API_SETTINGS](state, data) {
    Object.assign(state, data);
  },
  [types.RECEIVE_MANAGED_LICENSES_SUCCESS](state, licenses = []) {
    const managedLicenses = licenses.map(normalizeLicense).reverse();

    Object.assign(state, {
      managedLicenses,
      isLoadingManagedLicenses: false,
    });
  },
  [types.RECEIVE_MANAGED_LICENSES_ERROR](state) {
    Object.assign(state, {
      managedLicenses: [],
      isLoadingManagedLicenses: false,
    });
  },
  [types.REQUEST_MANAGED_LICENSES](state) {
    Object.assign(state, {
      isLoadingManagedLicenses: true,
    });
  },

  [types.RECEIVE_PARSED_LICENSE_REPORT_SUCCESS](state, { newLicenses, existingLicenses }) {
    Object.assign(state, {
      newLicenses,
      existingLicenses,
      isLoadingLicenseReport: false,
      loadLicenseReportError: false,
    });
  },
  [types.RECEIVE_PARSED_LICENSE_REPORT_ERROR](state, error) {
    Object.assign(state, {
      isLoadingLicenseReport: false,
      loadLicenseReportError: error,
    });
  },
  [types.REQUEST_PARSED_LICENSE_REPORT](state) {
    Object.assign(state, {
      isLoadingLicenseReport: true,
    });
  },
};
