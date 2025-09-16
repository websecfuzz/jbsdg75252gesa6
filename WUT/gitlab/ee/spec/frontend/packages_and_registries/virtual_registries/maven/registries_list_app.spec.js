import { GlAlert, GlEmptyState, GlSkeletonLoader } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { getMavenVirtualRegistriesList } from 'ee/api/virtual_registries_api';
import MavenRegistriesListApp from 'ee/packages_and_registries/virtual_registries/maven/registries_list_app.vue';
import MavenRegistryItem from 'ee/packages_and_registries/virtual_registries/components/maven_registry_item.vue';

jest.mock('ee/api/virtual_registries_api', () => ({
  getMavenVirtualRegistriesList: jest.fn(),
}));

describe('MavenRegistriesListApp', () => {
  let wrapper;

  const defaultProvide = {
    fullPath: 'gitlab-org',
  };

  const registriesMock = [
    {
      id: 1,
      name: 'Registry 1',
    },
    {
      id: 2,
      name: 'Registry 2',
    },
  ];

  const findSkeletonLoader = () => wrapper.findComponent(GlSkeletonLoader);
  const findAlert = () => wrapper.findComponent(GlAlert);
  const findEmptyState = () => wrapper.findComponent(GlEmptyState);
  const findRegistryItems = () => wrapper.findAllComponents(MavenRegistryItem);

  const createComponent = () => {
    wrapper = shallowMountExtended(MavenRegistriesListApp, {
      provide: {
        ...defaultProvide,
      },
    });
  };

  beforeEach(() => {
    getMavenVirtualRegistriesList.mockReset();
  });

  describe('component initialization', () => {
    it('calls the API with the correct parameters', () => {
      createComponent();

      expect(getMavenVirtualRegistriesList).toHaveBeenCalledWith({
        id: defaultProvide.fullPath,
      });
    });

    it('displays the skeleton loader during loading', () => {
      createComponent();

      expect(findSkeletonLoader().exists()).toBe(true);
      expect(findAlert().exists()).toBe(false);
      expect(findEmptyState().exists()).toBe(false);
      expect(findRegistryItems()).toHaveLength(0);
    });
  });

  describe('when the API returns data', () => {
    beforeEach(() => {
      getMavenVirtualRegistriesList.mockResolvedValue({ data: registriesMock });
    });

    it('displays the registry items with the correct props', async () => {
      createComponent();

      await waitForPromises();

      expect(findSkeletonLoader().exists()).toBe(false);
      expect(findAlert().exists()).toBe(false);
      expect(findEmptyState().exists()).toBe(false);

      const items = findRegistryItems();
      expect(items).toHaveLength(2);

      items.wrappers.forEach((item, i) => {
        expect(item.props()).toMatchObject({
          registry: registriesMock[i],
        });
      });
    });
  });

  describe('when the API returns an empty array', () => {
    beforeEach(() => {
      getMavenVirtualRegistriesList.mockResolvedValue({ data: [] });
    });

    it('displays the empty state', async () => {
      createComponent();

      await waitForPromises();

      expect(findSkeletonLoader().exists()).toBe(false);
      expect(findAlert().exists()).toBe(false);
      expect(findEmptyState().exists()).toBe(true);
      expect(findRegistryItems()).toHaveLength(0);
    });
  });

  describe('when the API call fails', () => {
    const errorMessage = 'API error';

    beforeEach(() => {
      getMavenVirtualRegistriesList.mockRejectedValue(new Error(errorMessage));
    });

    it('displays an error message', async () => {
      createComponent();

      await waitForPromises();

      expect(findSkeletonLoader().exists()).toBe(false);
      expect(findAlert().exists()).toBe(true);
      expect(findAlert().text()).toBe(errorMessage);
      expect(findEmptyState().exists()).toBe(false);
      expect(findRegistryItems()).toHaveLength(0);
    });
  });

  describe('when the API fails without an error message', () => {
    beforeEach(() => {
      getMavenVirtualRegistriesList.mockRejectedValue(new Error());
    });

    it('displays a default error message', async () => {
      createComponent();

      await waitForPromises();

      expect(findSkeletonLoader().exists()).toBe(false);
      expect(findAlert().exists()).toBe(true);
      expect(findAlert().text()).toBe('Failed to fetch list of maven virtual registries.');
      expect(findEmptyState().exists()).toBe(false);
      expect(findRegistryItems()).toHaveLength(0);
    });
  });
});
