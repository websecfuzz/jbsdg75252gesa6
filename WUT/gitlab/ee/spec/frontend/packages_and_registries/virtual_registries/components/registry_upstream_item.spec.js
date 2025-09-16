import { nextTick } from 'vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import RegistryUpstreamItem from 'ee/packages_and_registries/virtual_registries/components/registry_upstream_item.vue';

const defaultProps = {
  index: 1,
  upstreamsCount: 3,
  upstream: {
    id: 1,
    name: 'Upstream title',
    description: 'Upstream description',
    url: 'http://maven.org/test',
    cacheValidityHours: 24,
    position: 1,
    cacheSize: '100 MB',
    canClearCache: true,
    editPath: 'http://maven.org/test/edit',
    artifactCount: 100,
    warning: {
      text: 'Example warning text',
    },
  },
};

const defaultProvide = {
  glAbilities: {
    updateVirtualRegistry: true,
    destroyVirtualRegistry: true,
  },
  editUpstreamPathTemplate: 'path/:id/edit',
  showUpstreamPathTemplate: 'path/:id',
};

describe('RegistryUpstreamItem', () => {
  let wrapper;

  const createComponent = ({ props = {}, provide = {} } = {}) => {
    wrapper = shallowMountExtended(RegistryUpstreamItem, {
      propsData: {
        ...defaultProps,
        ...props,
      },
      provide: {
        ...defaultProvide,
        ...provide,
      },
      listeners: {
        reorderUpstream: jest.fn(),
      },
      stubs: {
        GlTruncate: {
          template: '<div>{{ text }}</div>',
          props: ['text'],
        },
      },
    });
  };

  const findUpstreamName = () => wrapper.findByTestId('upstream-name');
  const findUpstreamUrl = () => wrapper.findByTestId('upstream-url');
  const findCacheSize = () => wrapper.findByTestId('cache-size');
  const findCacheValidityHours = () => wrapper.findByTestId('cache-validity-hours');
  const findArtifactCount = () => wrapper.findByTestId('artifact-count');
  const findWarningBadge = () => wrapper.findByTestId('warning-badge');
  const findWarningText = () =>
    wrapper.findByTestId('warning-badge').find('button').attributes('title');
  const findClearCacheButton = () => wrapper.findByTestId('clear-cache-button');
  const findEditButton = () => wrapper.findByTestId('edit-button');
  const findDeleteButton = () => wrapper.findByTestId('delete-button');

  const findReorderUpButton = () => wrapper.findByTestId('reorder-up-button');
  const findReorderDownButton = () => wrapper.findByTestId('reorder-down-button');

  describe('renders', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders the reorder up button', () => {
      expect(findReorderUpButton().props('disabled')).toBe(false);
    });

    it('reorder up button is disabled if upstream is the first upstream', () => {
      createComponent({ props: { index: 0 } });
      expect(findReorderUpButton().props('disabled')).toBe(true);
    });

    it('renders the reorder down button', () => {
      expect(findReorderDownButton().props('disabled')).toBe(false);
    });

    it('reorder down button is disabled if upstream is the last upstream', () => {
      createComponent({ props: { index: 2 } });
      expect(findReorderDownButton().props('disabled')).toBe(true);
    });

    it('renders the upstream name', () => {
      expect(findUpstreamName().text()).toBe(defaultProps.upstream.name);
    });

    it('renders the upstream url', () => {
      expect(findUpstreamUrl().text()).toBe(defaultProps.upstream.url);
    });

    it('renders the cache size', () => {
      expect(findCacheSize().text()).toContain(defaultProps.upstream.cacheSize);
    });

    it('renders the cache validity hours', () => {
      expect(findCacheValidityHours().text()).toContain(
        defaultProps.upstream.cacheValidityHours.toLocaleString(),
      );
    });

    it('renders the artifact count', () => {
      expect(findArtifactCount().text()).toContain(
        defaultProps.upstream.artifactCount.toLocaleString(),
      );
    });

    it('renders the warning badge if upstream has a warning', () => {
      expect(findWarningBadge().exists()).toBe(true);
      expect(findWarningText()).toBe(defaultProps.upstream.warning.text);
    });

    it('renders the warning badge with default text if upstream has a warning but no text', () => {
      createComponent({
        props: { upstream: { ...defaultProps.upstream, warning: { text: null } } },
      });
      expect(findWarningText()).toBe('There is a problem with this cached upstream');
    });

    it('does not render the warning badge if upstream does not have a warning', () => {
      createComponent({ props: { upstream: { ...defaultProps.upstream, warning: null } } });
      expect(findWarningBadge().exists()).toBe(false);
    });

    it('renders the clear cache button if canClearCache is true', () => {
      expect(findClearCacheButton().exists()).toBe(true);
    });

    it('does not render the clear cache button if canClearCache is false', () => {
      createComponent({ props: { upstream: { ...defaultProps.upstream, canClearCache: false } } });
      expect(findClearCacheButton().exists()).toBe(false);
    });

    it('renders the edit button if canEdit is true and editPath is provided', () => {
      expect(findEditButton().exists()).toBe(true);
      expect(findEditButton().attributes('href')).toBe('path/1/edit');
    });

    it('does not render the edit button if canEdit is false', () => {
      createComponent({ provide: { glAbilities: { updateVirtualRegistry: false } } });
      expect(findEditButton().exists()).toBe(false);
    });

    it('renders the delete button if canDelete is true', () => {
      expect(findDeleteButton().exists()).toBe(true);
    });

    it('does not render the delete button if canDelete is false', () => {
      createComponent({ provide: { glAbilities: { destroyVirtualRegistry: false } } });
      expect(findDeleteButton().exists()).toBe(false);
    });
  });

  describe('emits events', () => {
    beforeEach(() => {
      createComponent();
    });

    it('emits reorderUp when reorder up button is clicked', async () => {
      findReorderUpButton().vm.$emit('click');
      await nextTick();
      expect(Boolean(wrapper.emitted('reorderUpstream'))).toBe(true);
      expect(wrapper.emitted('reorderUpstream')[0]).toEqual(['up', defaultProps.upstream.id]);
    });

    it('emits reorderDown when reorder down button is clicked', async () => {
      findReorderDownButton().vm.$emit('click');
      await nextTick();
      expect(Boolean(wrapper.emitted('reorderUpstream'))).toBe(true);
      expect(wrapper.emitted('reorderUpstream')[0]).toEqual(['down', defaultProps.upstream.id]);
    });

    it('emits clearCache when clear cache button is clicked', async () => {
      findClearCacheButton().vm.$emit('click');
      await nextTick();
      expect(Boolean(wrapper.emitted('clearCache'))).toBe(true);
      expect(wrapper.emitted('clearCache')[0]).toEqual([defaultProps.upstream.id]);
    });

    it('emits deleteUpstream when delete button is clicked', async () => {
      findDeleteButton().vm.$emit('click');
      await nextTick();
      expect(Boolean(wrapper.emitted('deleteUpstream'))).toBe(true);
      expect(wrapper.emitted('deleteUpstream')[0]).toEqual([defaultProps.upstream.id]);
    });
  });
});
