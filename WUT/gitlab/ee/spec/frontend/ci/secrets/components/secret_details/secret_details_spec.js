import { GlLabel } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import SecretDetails from 'ee/ci/secrets/components/secret_details/secret_details.vue';
import { mockSecret } from '../../mock_data';

describe('SecretDetails component', () => {
  let wrapper;

  const defaultProps = {
    fullPath: 'root/banana',
  };

  const findBranches = () => wrapper.findByTestId('secret-details-branches');
  const findDescription = () => wrapper.findByTestId('secret-details-description');
  const findEnvironments = () => wrapper.findComponent(GlLabel);

  const createComponent = ({ customSecret } = {}) => {
    wrapper = shallowMountExtended(SecretDetails, {
      propsData: {
        ...defaultProps,
        secret: {
          ...mockSecret(),
          ...customSecret,
        },
      },
    });
  };

  describe('template', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders and formats secret information', () => {
      expect(findDescription().text()).toBe('This is a secret');
      expect(findEnvironments().props('title')).toBe('env::staging');
      expect(findBranches().text()).toBe('main');
    });
  });

  describe('with required fields only', () => {
    beforeEach(() => {
      createComponent({
        customSecret: {
          description: undefined,
        },
      });
    });

    it("renders 'None' for optional fields that don't have values", () => {
      expect(findDescription().text()).toBe('None');
    });
  });
});
