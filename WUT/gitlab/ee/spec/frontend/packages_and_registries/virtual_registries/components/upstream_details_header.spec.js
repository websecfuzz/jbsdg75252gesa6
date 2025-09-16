import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import TitleArea from '~/vue_shared/components/registry/title_area.vue';
import MetadataItem from '~/vue_shared/components/registry/metadata_item.vue';
import UpstreamDetailsHeader from 'ee/packages_and_registries/virtual_registries/components/upstream_details_header.vue';
import { mockUpstream } from '../mock_data';

describe('UpstreamDetailsHeader', () => {
  let wrapper;

  const defaultProps = {
    upstream: mockUpstream,
  };

  const findTitleArea = () => wrapper.findComponent(TitleArea);
  const findAllMetadataItems = () => wrapper.findAllComponents(MetadataItem);
  const findDescription = () => wrapper.findByTestId('description');

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(UpstreamDetailsHeader, {
      propsData: {
        ...defaultProps,
        ...props,
      },
      stubs: {
        TitleArea,
      },
    });
  };

  describe('default', () => {
    beforeEach(() => {
      createComponent();
    });

    it('displays title area', () => {
      expect(findTitleArea().props('title')).toBe('Upstream Registry');
    });

    it('displays description', () => {
      expect(findDescription().text()).toBe('Upstream registry description');
    });

    it('displays metadata items', () => {
      expect(findAllMetadataItems()).toHaveLength(3);
    });
  });
});
