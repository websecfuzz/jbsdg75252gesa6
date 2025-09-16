import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import PublishMethod from '~/packages_and_registries/shared/components/publish_method.vue';
import { packageList } from 'jest/packages_and_registries/infrastructure_registry/components/mock_data';

describe('publish_method', () => {
  let wrapper;

  const [packageWithoutPipeline, packageWithPipeline] = packageList;

  const findPipelineRef = () => wrapper.findByTestId('pipeline-ref');
  const findPipelineSha = () => wrapper.findByTestId('pipeline-sha');
  const findManualPublish = () => wrapper.findByTestId('manually-published');

  const mountComponent = (packageEntity = {}, isGroup = false) => {
    wrapper = shallowMountExtended(PublishMethod, {
      propsData: {
        packageEntity,
        isGroup,
      },
    });
  };

  it('renders', () => {
    mountComponent(packageWithPipeline);
    expect(wrapper.element).toMatchSnapshot();
  });

  describe('pipeline information', () => {
    it('displays branch and commit when pipeline info exists', () => {
      mountComponent(packageWithPipeline);

      expect(findPipelineRef().exists()).toBe(true);
      expect(findPipelineSha().exists()).toBe(true);
    });

    it('does not show any pipeline details when no information exists', () => {
      mountComponent(packageWithoutPipeline);

      expect(findPipelineRef().exists()).toBe(false);
      expect(findPipelineSha().exists()).toBe(false);
      expect(findManualPublish().exists()).toBe(true);
      expect(findManualPublish().text()).toBe('Manually published');
    });
  });
});
