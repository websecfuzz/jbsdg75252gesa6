<script>
import { GlButton, GlCollapsibleListbox } from '@gitlab/ui';
import { debounce } from 'lodash';
import { searchInItemsProperties } from '~/lib/utils/search_utils';
import { s__ } from '~/locale';
import { DEFAULT_DEBOUNCE_AND_THROTTLE_MS } from '~/lib/utils/constants';
import {
  getUserName,
  isValidServiceAccount,
} from 'ee/security_orchestration/components/policy_editor/scan_result/advanced_settings/utils';
import ServiceAccountsTokenSelector from './service_accounts_token_selector.vue';

export default {
  name: 'ServiceAccountsItem',
  i18n: {
    accountsHeader: s__('ScanResultPolicy|Select service accounts'),
    serviceAccountDefaultText: s__('ScanResultPolicy|Select service account'),
  },
  components: {
    GlButton,
    GlCollapsibleListbox,
    ServiceAccountsTokenSelector,
  },
  props: {
    loading: {
      type: Boolean,
      required: false,
      default: false,
    },
    alreadySelectedUsernames: {
      type: Array,
      required: false,
      default: () => [],
    },
    serviceAccounts: {
      type: Array,
      required: false,
      default: () => [],
    },
    selectedItem: {
      type: Object,
      required: false,
      default: () => ({}),
    },
  },
  data() {
    return {
      searchTerm: '',
    };
  },
  computed: {
    selectedUserName() {
      return getUserName(this.selectedItem);
    },
    selectedServiceAccount() {
      return this.findServiceAccount(this.selectedUserName) || {};
    },
    selectedTokensIds() {
      return this.selectedItem?.tokens?.map(({ id }) => id) || [];
    },
    toggleText() {
      return this.selectedServiceAccount.name || this.$options.i18n.serviceAccountDefaultText;
    },
    listBoxItems() {
      const alreadySelectedItems = ({ username }) =>
        username === this.selectedUserName || !this.alreadySelectedUsernames?.includes(username);
      const mapToListBoxItem = ({ name, username }) => ({ text: name, value: username });

      return this.serviceAccounts
        ?.filter(isValidServiceAccount)
        .filter(alreadySelectedItems)
        .map(mapToListBoxItem);
    },
    filteredItems() {
      return searchInItemsProperties({
        items: this.listBoxItems,
        properties: ['text', 'value'],
        searchQuery: this.searchTerm,
      });
    },
  },
  created() {
    this.debouncedSearch = debounce(this.setSearchTerm, DEFAULT_DEBOUNCE_AND_THROTTLE_MS);
  },
  destroyed() {
    this.debouncedSearch.cancel();
  },
  methods: {
    findServiceAccount(username = '') {
      return this.serviceAccounts?.filter(Boolean).find((account) => account.username === username);
    },
    removeItem() {
      this.$emit('remove');
    },
    setSearchTerm(term) {
      this.searchTerm = term;
    },
    setServiceAccount(username) {
      this.$emit('set-account', { account: { username } });
    },
    setTokens(tokens) {
      this.$emit('set-account', {
        ...this.selectedItem,
        tokens,
      });
    },
  },
};
</script>

<template>
  <div class="gl-flex gl-w-full gl-flex-col gl-gap-5 md:gl-flex-row md:gl-items-center">
    <div class="gl-flex gl-w-full gl-flex-col gl-items-center gl-gap-3 md:gl-flex-row">
      <gl-collapsible-listbox
        block
        searchable
        class="gl-w-full gl-flex-1"
        :loading="loading"
        :items="filteredItems"
        :header-text="$options.i18n.accountsHeader"
        :toggle-text="toggleText"
        :selected="selectedUserName"
        @search="debouncedSearch"
        @select="setServiceAccount"
      />

      <service-accounts-token-selector
        class="gl-flex-1"
        :account-id="selectedServiceAccount.id"
        :selected-tokens-ids="selectedTokensIds"
        @loading-error="$emit('token-loading-error')"
        @set-tokens="setTokens"
      />
    </div>

    <gl-button :aria-label="__('Remove')" icon="remove" @click="removeItem" />
  </div>
</template>
