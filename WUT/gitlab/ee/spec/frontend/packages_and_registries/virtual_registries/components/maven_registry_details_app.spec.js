import { GlButton } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import MavenRegistryDetailsApp from 'ee/packages_and_registries/virtual_registries/components/maven_registry_details_app.vue';
import TitleArea from '~/vue_shared/components/registry/title_area.vue';
import MetadataItem from '~/vue_shared/components/registry/metadata_item.vue';
import CrudComponent from '~/vue_shared/components/crud_component.vue';
import RegistryUpstreamItem from 'ee/packages_and_registries/virtual_registries/components/registry_upstream_item.vue';
import RegistryUpstreamForm from 'ee/packages_and_registries/virtual_registries/components/registry_upstream_form.vue';

describe('MavenRegistryDetailsApp', () => {
  let wrapper;

  const defaultProps = {
    registry: {
      id: 1,
      name: 'Registry title',
      description: 'Registry description',
    },
    upstreams: {
      count: 1,
      nodes: [
        {
          id: 1,
          name: 'Upstream title',
          description: 'Upstream description',
          url: 'http://maven.org/test',
          cacheValidityHours: 24,
          position: 1,
          cacheSize: '100 MB',
          canClearCache: true,
          warning: {
            text: 'Example warning text',
          },
        },
      ],
      pageInfo: {
        startCursor: 'eyJ1cHN0cmVhbV9pZCI6IjEifQ',
        hasNextPage: false,
        hasPreviousPage: false,
        endCursor: 'eyJ1cHN0cmVhbV9pZCI6IjEifQ',
      },
    },
  };

  const defaultProvide = {
    registryEditPath: 'edit_path',
    glAbilities: {
      createVirtualRegistry: true,
      updateVirtualRegistry: true,
    },
  };

  const findDescription = () => wrapper.findByTestId('description');
  const findTitleArea = () => wrapper.findComponent(TitleArea);
  const findButton = () => wrapper.findComponent(GlButton);
  const findCrudComponent = () => wrapper.findComponent(CrudComponent);
  const findMetadataItems = () => wrapper.findAllComponents(MetadataItem);
  const findUpstreams = () => wrapper.findAllComponents(RegistryUpstreamItem);

  const createComponent = ({ props = {}, provide = {} } = {}) => {
    wrapper = shallowMountExtended(MavenRegistryDetailsApp, {
      propsData: {
        ...defaultProps,
        ...props,
      },
      provide: {
        ...defaultProvide,
        ...provide,
      },
      stubs: {
        TitleArea,
      },
    });
  };

  describe('component rendering', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders the TitleArea component with correct props', () => {
      expect(findTitleArea().props('title')).toBe(defaultProps.registry.name);
    });

    it('renders the description', () => {
      expect(findDescription().text()).toBe(defaultProps.registry.description);
    });

    it('renders the Crud component with correct props', () => {
      expect(findCrudComponent().props()).toMatchObject({
        title: 'Upstreams',
        icon: 'infrastructure-registry',
        count: defaultProps.upstreams.count,
        toggleText: 'Add upstream',
      });
    });

    it('does not set toggleText prop on Crud component when user does not have ability', () => {
      createComponent({ provide: { glAbilities: { createVirtualRegistry: false } } });

      expect(findCrudComponent().props('toggleText')).toBeNull();
    });

    it('renders the upstreams and passes correct props to each', () => {
      const upstreams = findUpstreams();

      expect(upstreams).toHaveLength(defaultProps.upstreams.count);
      expect(upstreams.at(0).props()).toMatchObject({
        upstream: defaultProps.upstreams.nodes[0],
      });
    });

    it('shows create form when toggleText is clicked', () => {
      findCrudComponent().vm.$emit('toggle');
      expect(wrapper.findComponent(RegistryUpstreamForm).exists()).toBe(true);
    });

    it('renders the edit button with correct href', () => {
      expect(findButton().attributes('href')).toBe(defaultProvide.registryEditPath);
    });

    it('hides the edit button if user does not have ability', () => {
      createComponent({ provide: { glAbilities: { updateVirtualRegistry: false } } });

      expect(findButton().exists()).toBe(false);
    });
  });

  describe('metadata items', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders the registry type metadata item', () => {
      const registryTypeItem = findMetadataItems().at(0);

      expect(registryTypeItem.props('icon')).toBe('infrastructure-registry');
      expect(registryTypeItem.props('text')).toBe('Maven');
    });
  });
});
