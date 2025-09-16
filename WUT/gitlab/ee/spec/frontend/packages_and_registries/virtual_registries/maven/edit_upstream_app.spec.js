import { nextTick } from 'vue';
import { GlAlert, GlButton, GlModal } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { visitUrlWithAlerts } from '~/lib/utils/url_utility';
import { updateMavenUpstream, deleteMavenUpstream } from 'ee/api/virtual_registries_api';
import RegistryUpstreamForm from 'ee/packages_and_registries/virtual_registries/components/registry_upstream_form.vue';
import MavenEditUpstreamApp from 'ee/packages_and_registries/virtual_registries/maven/edit_upstream_app.vue';

jest.mock('~/lib/utils/url_utility', () => ({
  ...jest.requireActual('~/lib/utils/url_utility'),
  visitUrlWithAlerts: jest.fn(),
}));

jest.mock('ee/api/virtual_registries_api', () => ({
  updateMavenUpstream: jest.fn(),
  deleteMavenUpstream: jest.fn(),
}));

describe('MavenEditUpstreamApp', () => {
  let wrapper;

  const defaultProvide = {
    upstream: {
      id: 1,
      name: 'Upstream',
      url: 'http://local.test/maven/',
      description: null,
      username: null,
      cacheValidityHours: 24,
    },
    registriesPath: '/groups/package-group/-/virtual_registries',
    upstreamPath: '/groups/package-group/-/virtual_registries/maven/upstreams/3',
    glAbilities: {
      destroyVirtualRegistry: true,
    },
  };

  const findModal = () => wrapper.findComponent(GlModal);
  const findAlert = () => wrapper.findComponent(GlAlert);
  const findDeleteUpstreamBtn = () => wrapper.findComponent(GlButton);
  const findForm = () => wrapper.findComponent(RegistryUpstreamForm);

  const createComponent = (provide) => {
    wrapper = shallowMountExtended(MavenEditUpstreamApp, {
      provide: {
        ...defaultProvide,
        ...provide,
      },
    });
  };

  beforeEach(() => {
    updateMavenUpstream.mockReset();
    deleteMavenUpstream.mockReset();
  });

  describe('render', () => {
    it('displays registry form', () => {
      createComponent();

      expect(findForm().exists()).toBe(true);
      expect(findForm().props('upstream')).toStrictEqual({
        id: 1,
        name: 'Upstream',
        url: 'http://local.test/maven/',
        description: null,
        username: null,
        cacheValidityHours: 24,
      });
    });
  });

  describe('updating registry', () => {
    it('calls deleteUpstream API with correct ID', async () => {
      createComponent();

      const formData = {
        name: 'New Upstream',
        url: 'http://local.test/maven/',
        description: 'description',
        username: null,
        cacheValidityHours: 24,
      };

      findForm().vm.$emit('submit', formData);

      await nextTick();

      expect(updateMavenUpstream).toHaveBeenCalledWith({ data: formData, id: 1 });
      expect(visitUrlWithAlerts).toHaveBeenCalled();
    });

    it('shows error alert on failure', async () => {
      updateMavenUpstream.mockRejectedValue(new Error('API error'));

      createComponent();

      expect(findAlert().exists()).toBe(false);

      findForm().vm.$emit('submit');

      await waitForPromises();

      expect(findAlert().exists()).toBe(true);
      expect(findAlert().text()).toBe('API error');
    });
  });

  describe('deleting registry', () => {
    it('does not show delete button', () => {
      createComponent({
        glAbilities: {
          destroyVirtualRegistry: false,
        },
      });

      expect(findDeleteUpstreamBtn().exists()).toBe(false);
    });

    it('shows delete modal on delete upstream button click', async () => {
      createComponent();

      expect(findModal().props('visible')).toBe(false);

      findDeleteUpstreamBtn().vm.$emit('click');

      await nextTick();

      expect(findModal().props('visible')).toBe(true);
    });

    it('calls updateMavenUpstream API with correct data', async () => {
      createComponent();

      findModal().vm.$emit('primary');

      await nextTick();

      expect(deleteMavenUpstream).toHaveBeenCalledWith({
        id: 1,
      });
      expect(visitUrlWithAlerts).toHaveBeenCalled();
    });

    it('shows error alert on failure', async () => {
      deleteMavenUpstream.mockRejectedValue(new Error('API error'));

      createComponent();

      expect(findAlert().exists()).toBe(false);

      findModal().vm.$emit('primary');

      await waitForPromises();

      expect(findAlert().exists()).toBe(true);
      expect(findAlert().text()).toBe('API error');
    });
  });
});
