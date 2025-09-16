import { GlButton, GlCollapsibleListbox } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import ServiceAccountsItem from 'ee/security_orchestration/components/policy_editor/scan_result/advanced_settings/policy_exceptions/service_accounts_item.vue';
import ServiceAccountsTokenSelector from 'ee/security_orchestration/components/policy_editor/scan_result/advanced_settings/policy_exceptions/service_accounts_token_selector.vue';
import { mockServiceAccounts } from 'ee_jest/security_orchestration/components/policy_editor/scan_result/advanced_settings/policy_exceptions/mocks';

describe('ServiceAccountsItem', () => {
  let wrapper;

  const defaultProps = {
    loading: false,
    alreadySelectedUsernames: [],
    serviceAccounts: mockServiceAccounts,
    selectedItem: {
      id: 'account_1',
      account: { username: 'sa1' },
      tokens: [{ id: 1 }, { id: 2 }],
    },
  };

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(ServiceAccountsItem, {
      propsData: {
        ...defaultProps,
        ...props,
      },
    });
  };

  const findCollapsibleListbox = () => wrapper.findComponent(GlCollapsibleListbox);
  const findTokenSelector = () => wrapper.findComponent(ServiceAccountsTokenSelector);
  const findRemoveButton = () => wrapper.findComponent(GlButton);

  describe('Props', () => {
    describe('loading', () => {
      it.each([false, true])('passes loading state to listbox', (loading) => {
        createComponent({ loading });
        expect(findCollapsibleListbox().props('loading')).toBe(loading);
      });
    });

    describe('alreadySelectedUsernames', () => {
      it('filters out already selected usernames from listbox items', () => {
        createComponent({ alreadySelectedUsernames: ['sa2', 'sa3'] });

        expect(findCollapsibleListbox().props('items')).toEqual([
          { text: 'service-account-1', value: 'sa1' },
        ]);
      });

      it('includes current selected username even if in already selected list', () => {
        createComponent({
          alreadySelectedUsernames: ['sa1', 'sa2'],
          selectedItem: { account: { username: 'sa1' } },
        });

        expect(findCollapsibleListbox().props('items')).toEqual([
          { text: 'service-account-1', value: 'sa1' },
          { text: 'service-account-3', value: 'sa3' },
        ]);
      });

      it('handles empty array', () => {
        createComponent({ alreadySelectedUsernames: [] });

        expect(findCollapsibleListbox().props('items')).toHaveLength(3);
      });

      it('handles null value', () => {
        createComponent({ alreadySelectedUsernames: null });

        expect(findCollapsibleListbox().props('items')).toHaveLength(3);
      });
    });

    describe('serviceAccounts', () => {
      it('renders listbox items from service accounts', () => {
        createComponent();

        expect(findCollapsibleListbox().props('items')).toEqual([
          { text: 'service-account-1', value: 'sa1' },
          { text: 'service-account-2', value: 'sa2' },
          { text: 'service-account-3', value: 'sa3' },
        ]);
      });

      it('handles empty service accounts array', () => {
        createComponent({ serviceAccounts: [] });

        expect(findCollapsibleListbox().props('items')).toEqual([]);
      });

      it('handles null service accounts', () => {
        createComponent({ serviceAccounts: null });

        expect(findCollapsibleListbox().props('items')).toEqual([]);
      });

      it('handles malformed service account objects', () => {
        const malformedAccounts = [
          { id: 1, name: 'account-1' }, // missing username
          { username: 'sa2' }, // missing name
          null,
          { id: 3, name: 'account-3', username: 'sa3' },
        ];

        createComponent({ serviceAccounts: malformedAccounts });

        expect(findCollapsibleListbox().props('items')).toEqual([
          { text: 'account-3', value: 'sa3' },
        ]);
      });
    });

    describe('selectedItem', () => {
      it('displays selected service account name in toggle text', () => {
        createComponent();
        expect(findCollapsibleListbox().props('toggleText')).toBe('service-account-1');
      });

      it('shows default text when no account selected', () => {
        createComponent({ selectedItem: {} });
        expect(findCollapsibleListbox().props('toggleText')).toBe('Select service account');
      });

      it('passes selected username to listbox', () => {
        createComponent();
        expect(findCollapsibleListbox().props('selected')).toBe('sa1');
      });

      it('passes account ID to token selector', () => {
        createComponent();
        expect(findTokenSelector().props('accountId')).toBe(1);
      });

      it('passes selected token IDs to token selector', () => {
        createComponent();
        expect(findTokenSelector().props('selectedTokensIds')).toEqual([1, 2]);
      });

      it('handles selectedItem without tokens', () => {
        createComponent({
          selectedItem: { account: { username: 'sa1' } },
        });
        expect(findTokenSelector().props('selectedTokensIds')).toEqual([]);
      });

      it('handles empty selectedItem', () => {
        createComponent({ selectedItem: {} });
        expect(findCollapsibleListbox().props('selected')).toBe('');
        expect(findTokenSelector().props('accountId')).toBe(undefined);
      });

      it('handles null selectedItem', () => {
        createComponent({ selectedItem: null });

        expect(findCollapsibleListbox().props('selected')).toBe('');
        expect(findTokenSelector().props('accountId')).toBe(undefined);
      });
    });
  });

  describe('Events', () => {
    describe('set-account event', () => {
      it('emits set-account when service account is selected', async () => {
        createComponent();
        await findCollapsibleListbox().vm.$emit('select', 'sa2');

        expect(wrapper.emitted('set-account')).toHaveLength(1);
        expect(wrapper.emitted('set-account')[0]).toEqual([{ account: { username: 'sa2' } }]);
      });

      it('emits set-account with tokens when tokens are updated', async () => {
        createComponent();
        const newTokens = [{ id: 3 }, { id: 4 }];
        await findTokenSelector().vm.$emit('set-tokens', newTokens);

        expect(wrapper.emitted('set-account')).toHaveLength(1);
        expect(wrapper.emitted('set-account')[0]).toEqual([
          {
            ...defaultProps.selectedItem,
            tokens: newTokens,
          },
        ]);
      });
    });

    describe('remove event', () => {
      it('emits remove when remove button is clicked', async () => {
        createComponent();
        await findRemoveButton().vm.$emit('click');

        expect(wrapper.emitted('remove')).toHaveLength(1);
      });
    });

    describe('token-loading-error event', () => {
      it('forwards token-loading-error from token selector', async () => {
        createComponent();
        await findTokenSelector().vm.$emit('loading-error');

        expect(wrapper.emitted('token-loading-error')).toHaveLength(1);
      });
    });
  });
});
