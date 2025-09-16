import { shallowMount } from '@vue/test-utils';
import ScannerProfileSelector from 'ee/security_configuration/dast_profiles/dast_profile_selector/scanner_profile_selector.vue';
import EmptyState from 'ee/security_configuration/dast_profiles/dast_profile_selector/empty_state.vue';
import { scannerProfiles } from 'ee_jest/security_configuration/dast_profiles/mocks/mock_data';
import { extendedWrapper } from 'helpers/vue_test_utils_helper';

describe('ScannerProfileSelector', () => {
  let wrapper;

  const createComponent = (props) => {
    wrapper = extendedWrapper(
      shallowMount(ScannerProfileSelector, {
        propsData: {
          profiles: [],
          props,
        },
        stubs: {
          EmptyState,
        },
      }),
    );
  };

  const findSelectProfileBtn = () => wrapper.findByTestId('select-profile-action-btn');

  it('renders properly with no profiles', () => {
    createComponent({});

    expect(wrapper.element).toMatchSnapshot();
  });

  it('renders properly with profiles', () => {
    createComponent({
      profiles: scannerProfiles,
      selectedProfile: scannerProfiles[0],
    });
    expect(wrapper.element).toMatchSnapshot();
  });

  it('action button should emit correct event', () => {
    createComponent();

    expect(findSelectProfileBtn().exists()).toBe(true);

    findSelectProfileBtn().vm.$emit('click');
    expect(wrapper.emitted('open-drawer')).toHaveLength(1);
  });
});
