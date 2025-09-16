import Vue from 'vue';
import { PiniaVuePlugin } from 'pinia';
import { GlButton, GlDisclosureDropdown, GlPagination, GlTable } from '@gitlab/ui';
import { createTestingPinia } from '@pinia/testing';
import { mountExtended } from 'helpers/vue_test_utils_helper';

import { useServiceAccounts } from 'ee/service_accounts/stores/service_accounts';
import CreateEditServiceAccountModal from 'ee/service_accounts/components/create_edit_service_account_modal.vue';
import DeleteServiceAccountModal from 'ee/service_accounts/components/delete_service_account_modal.vue';
import ServiceAccounts from 'ee/service_accounts/components/service_accounts.vue';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import { TEST_HOST } from 'helpers/test_constants';

Vue.use(PiniaVuePlugin);

let wrapper;

const findPagination = () => wrapper.findComponent(GlPagination);
const findPageHeading = () => wrapper.findComponent(PageHeading);
const findAddServiceAccountButton = () => findPageHeading().findComponent(GlButton);
const findTable = () => wrapper.findComponent(GlTable);
const findDisclosure = () => wrapper.findComponent(GlDisclosureDropdown);
const findDisclosureButton = (index) =>
  findDisclosure().findAll('button.gl-new-dropdown-item-content').at(index);
const findDeleteModal = () => wrapper.findComponent(DeleteServiceAccountModal);
const findCreateEditServiceAccountModal = () =>
  wrapper.findComponent(CreateEditServiceAccountModal);

describe('Service accounts', () => {
  const serviceAccountsPath = `${TEST_HOST}/service_accounts`;
  const serviceAccountsEditPath = `${TEST_HOST}/service_accounts`;
  const serviceAccountsDeletePath = `${TEST_HOST}/api/v4/users`;
  const serviceAccountsDocsPath = `${TEST_HOST}/ee/user/profile/service_accounts.html`;
  const isGroup = false;

  const pinia = createTestingPinia();
  const store = useServiceAccounts();

  const $router = {
    push: jest.fn(),
  };

  const createComponent = (provide = {}) => {
    wrapper = mountExtended(ServiceAccounts, {
      pinia,
      mocks: {
        $router,
      },
      provide: {
        isGroup,
        serviceAccountsPath,
        serviceAccountsEditPath,
        serviceAccountsDeletePath,
        serviceAccountsDocsPath,
        ...provide,
      },
    });
  };

  const values = {
    name: 'Service Account 1',
    username: 'test_user',
  };

  beforeAll(() => {
    store.serviceAccounts = [{ id: 1, ...values }];
  });

  beforeEach(() => {
    createComponent();
  });

  it('fetches service accounts when it is rendered', () => {
    expect(store.fetchServiceAccounts).toHaveBeenCalledWith(serviceAccountsPath, { page: 1 });
  });

  it('fetches service accounts when the page is changed', () => {
    findPagination().vm.$emit('input', 2);

    expect(store.fetchServiceAccounts).toHaveBeenCalledWith(serviceAccountsPath, { page: 2 });
  });

  describe('table', () => {
    describe('busy state', () => {
      describe('when it is `true`', () => {
        beforeAll(() => {
          store.busy = true;
        });

        afterAll(() => {
          store.busy = false;
        });

        it('has aria-busy `true` in the table', () => {
          expect(findTable().attributes('aria-busy')).toBe('true');
        });

        it('disables the dropdown', () => {
          expect(findDisclosure().props('disabled')).toBe(true);
        });
      });

      describe('when it is `false`', () => {
        it('has aria-busy `false` in the table', () => {
          expect(findTable().attributes('aria-busy')).toBe('false');
        });

        it('enables the dropdown', () => {
          expect(findDisclosure().props('disabled')).toBe(false);
        });
      });
    });

    describe('headers', () => {
      it('should have name', () => {
        const header = wrapper.findByTestId('header-name');
        expect(header.text()).toBe('Name');
      });
    });

    describe('cells', () => {
      describe('name', () => {
        it('shows the service account name and username', () => {
          const name = wrapper.findByTestId('service-account-name');
          const username = wrapper.findByTestId('service-account-username');
          expect(name.text()).toBe('Service Account 1');
          expect(username.text()).toBe('@test_user');
        });
      });

      describe('options', () => {
        it('shows the options dropdown', () => {
          const options = wrapper.findByTestId('cell-options').findComponent(GlDisclosureDropdown);
          expect(options.props('items')).toMatchObject([
            {
              text: 'Manage access tokens',
            },
            {
              text: 'Edit',
            },
            {
              text: 'Delete account',
              variant: 'danger',
            },
            {
              text: 'Delete account and contributions',
              variant: 'danger',
            },
          ]);
        });

        describe('when click on the manage access token button', () => {
          it('routes to the token management', () => {
            findDisclosureButton(0).trigger('click');

            expect($router.push).toHaveBeenCalledWith({
              name: 'access_tokens',
              params: { id: 1 },
              replace: true,
            });
          });

          it('clears alerts', () => {
            expect(store.clearAlert).toHaveBeenCalledTimes(0);
            findDisclosureButton(0).trigger('click');

            expect(store.clearAlert).toHaveBeenCalledTimes(1);
          });
        });

        describe('when click on the edit button', () => {
          it('set the account and delete type when click on the delete account button', () => {
            findDisclosureButton(1).trigger('click');

            expect(store.setServiceAccount).toHaveBeenCalledWith({
              id: 1,
              name: 'Service Account 1',
              username: 'test_user',
            });
            expect(store.setCreateEditType).toHaveBeenCalledWith('edit');
          });

          it('clears alerts', () => {
            expect(store.clearAlert).toHaveBeenCalledTimes(0);
            findDisclosureButton(1).trigger('click');

            expect(store.clearAlert).toHaveBeenCalledTimes(1);
          });
        });

        describe('when click on the delete account button', () => {
          it('set the account and delete type when click on the delete account button', () => {
            findDisclosureButton(2).trigger('click');

            expect(store.setServiceAccount).toHaveBeenCalledWith({
              id: 1,
              name: 'Service Account 1',
              username: 'test_user',
            });
            expect(store.setDeleteType).toHaveBeenCalledWith('soft');
          });

          it('clears alerts', () => {
            expect(store.clearAlert).toHaveBeenCalledTimes(0);
            findDisclosureButton(2).trigger('click');

            expect(store.clearAlert).toHaveBeenCalledTimes(1);
          });
        });

        describe('when click on the delete account and contribution button', () => {
          it('sets the account and delete type', () => {
            findDisclosureButton(3).trigger('click');

            expect(store.setServiceAccount).toHaveBeenCalledWith({
              id: 1,
              name: 'Service Account 1',
              username: 'test_user',
            });
            expect(store.setDeleteType).toHaveBeenCalledWith('hard');
          });

          it('clears alerts', () => {
            expect(store.clearAlert).toHaveBeenCalledTimes(0);
            findDisclosureButton(3).trigger('click');

            expect(store.clearAlert).toHaveBeenCalledTimes(1);
          });
        });
      });
    });

    describe('empty', () => {
      beforeEach(() => {
        store.serviceAccounts = [];
      });

      it('shows table with no service accounts', () => {
        expect(findTable().find('.b-table-empty-row').text()).toBe('No service accounts');
      });
    });
  });

  describe('header', () => {
    it('shows the page heading', () => {
      const heading = findPageHeading();
      expect(heading.text()).toContain(
        'Service accounts are non-human accounts that allow interactions between software applications, systems, or services. Learn more',
      );
    });

    it('triggers the add service account action', () => {
      const addServiceAccountButton = findAddServiceAccountButton();

      addServiceAccountButton.vm.$emit('click');

      expect(addServiceAccountButton.emitted()).toHaveProperty('click');
      expect(store.clearAlert).toHaveBeenCalled();
      expect(store.setCreateEditType).toHaveBeenCalledWith('create');
      expect(store.setServiceAccount).toHaveBeenCalledWith(null);
    });
  });

  describe('modals', () => {
    describe('delete', () => {
      beforeEach(() => {
        store.deleteType = 'soft';
        store.serviceAccount = {
          id: 1,
          name: 'Service Account 1',
          username: 'test user',
        };
        createComponent();
      });

      it('shows the modal when the deleteType is set', () => {
        expect(findDeleteModal().exists()).toBe(true);
      });

      it('call deleteUser when modal is submitted', () => {
        findDeleteModal().vm.$emit('submit');

        expect(store.deleteUser).toHaveBeenCalledWith(serviceAccountsDeletePath);
      });

      it('resets deleteType when modal is cancelled', () => {
        findDeleteModal().vm.$emit('cancel');

        expect(store.setDeleteType).toHaveBeenCalledWith(null);
      });
    });

    describe('create', () => {
      beforeEach(() => {
        store.createEditType = 'create';
        createComponent();
      });

      it('shows the modal when the createEditType is set', () => {
        expect(findCreateEditServiceAccountModal().exists()).toBe(true);
      });

      it('call createServiceAccount when modal is submitted', () => {
        findCreateEditServiceAccountModal().vm.$emit('submit', values);

        expect(store.createServiceAccount).toHaveBeenCalledWith(serviceAccountsPath, values);
      });

      it('resets createEditType when modal is cancelled', () => {
        findCreateEditServiceAccountModal().vm.$emit('cancel');

        expect(store.setCreateEditType).toHaveBeenCalledWith(null);
      });
    });

    describe('edit', () => {
      beforeEach(() => {
        store.createEditType = 'edit';
        createComponent();
      });

      it('shows the modal when the createEditType is set', () => {
        expect(findCreateEditServiceAccountModal().exists()).toBe(true);
      });

      describe('when in admin area', () => {
        it('call editServiceAccount when modal is submitted', () => {
          findCreateEditServiceAccountModal().vm.$emit('submit', values);

          expect(store.editServiceAccount).toHaveBeenCalledWith(serviceAccountsPath, values, false);
        });
      });

      describe('when in the group area', () => {
        it('call editServiceAccount when modal is submitted', () => {
          createComponent({ isGroup: true });
          findCreateEditServiceAccountModal().vm.$emit('submit', values);

          expect(store.editServiceAccount).toHaveBeenCalledWith(serviceAccountsPath, values, true);
        });
      });

      it('resets createEditType when modal is cancelled', () => {
        findCreateEditServiceAccountModal().vm.$emit('cancel');

        expect(store.setCreateEditType).toHaveBeenCalledWith(null);
      });
    });
  });
});
