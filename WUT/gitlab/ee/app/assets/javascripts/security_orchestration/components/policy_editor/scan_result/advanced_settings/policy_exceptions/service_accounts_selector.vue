<script>
import { GlAlert, GlButton } from '@gitlab/ui';
import { s__ } from '~/locale';
import Api from '~/api';
import ServiceAccountsItem from 'ee/security_orchestration/components/policy_editor/scan_result/advanced_settings/policy_exceptions/service_accounts_item.vue';
import {
  createServiceAccountObject,
  getUserName,
  removeIds,
} from 'ee/security_orchestration/components/policy_editor/scan_result/advanced_settings/utils';

export default {
  FORM_ID: 'accounts-list',
  RECENTLY_USED_ACCOUNTS_MAX: 3,
  i18n: {
    title: s__('ScanResultPolicy|Select service accounts'),
    serviceAccountTypeName: s__('ScanResultPolicy|service account'),
    accountsHeader: s__('ScanResultPolicy|Service accounts'),
  },
  name: 'ServiceAccountsSelector',
  components: {
    GlAlert,
    GlButton,
    ServiceAccountsItem,
  },
  inject: ['rootNamespacePath'],
  props: {
    selectedAccounts: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  data() {
    return {
      loading: false,
      serviceAccounts: [],
      showAlert: false,
      items: this.mapSelectedAccounts(this.selectedAccounts),
    };
  },
  computed: {
    addButtonDisabled() {
      return this.allSelected || this.loading;
    },
    allSelected() {
      return this.items.length === this.serviceAccounts.length;
    },
    selectedAccountsUsernames() {
      return this.selectedAccounts.map(getUserName);
    },
  },
  async mounted() {
    try {
      this.setLoading(true);
      const { data } = await Api.groupServiceAccounts(this.rootNamespacePath);
      this.serviceAccounts = data;
    } catch {
      this.showErrorMessage();
    } finally {
      this.setLoading(false);
    }
  },
  methods: {
    addAccount() {
      this.items = [...this.items, createServiceAccountObject()];
    },
    mapSelectedAccounts(accounts) {
      return accounts.length > 0
        ? accounts.map(createServiceAccountObject)
        : [createServiceAccountObject()];
    },
    removeServiceAccount(id) {
      this.items = this.items.filter((item) => item.id !== id);
      this.emitAction();
    },
    setAccount(account, index) {
      this.items.splice(index, 1, account);
      this.emitAction();
    },
    emitAction() {
      this.$emit('set-accounts', removeIds(this.items));
    },
    showErrorMessage() {
      this.showAlert = true;
    },
    setLoading(loading) {
      this.loading = loading;
    },
  },
};
</script>

<template>
  <div class="gl-w-full gl-px-3 gl-py-4">
    <div class="gl-mb-3 gl-hidden gl-w-full md:gl-flex">
      <p class="gl-mb-0 gl-flex-1 gl-font-bold">
        {{ s__('ScanResultPolicy|Select service account') }}
      </p>
      <p class="gl-mb-0 gl-flex-1 gl-pr-8 gl-font-bold">
        {{ s__('ScanResultPolicy|Personal access token') }}
      </p>
    </div>

    <div class="gl-mb-4 gl-flex gl-flex-col gl-gap-4">
      <service-accounts-item
        v-for="(item, index) of items"
        :key="item.id"
        :loading="loading"
        :already-selected-usernames="selectedAccountsUsernames"
        :selected-item="item"
        :service-accounts="serviceAccounts"
        @token-loading-error="showErrorMessage"
        @remove="removeServiceAccount(item.id)"
        @set-account="setAccount($event, index)"
      />
    </div>

    <gl-button
      data-testid="add-service-account"
      :disabled="addButtonDisabled"
      icon="plus"
      category="tertiary"
      variant="confirm"
      size="small"
      @click="addAccount"
    >
      {{ s__('ScanResultPolicy|Add another account') }}
    </gl-button>

    <gl-alert v-if="showAlert" class="gl-mt-4" variant="danger" :dismissible="false">
      {{ s__('ScanResultPolicy|Error while fetching') }}
    </gl-alert>
  </div>
</template>
