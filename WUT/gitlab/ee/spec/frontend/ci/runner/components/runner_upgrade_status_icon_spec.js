import { GlIcon } from '@gitlab/ui';
import { mount } from '@vue/test-utils';
import { createMockDirective, getBinding } from 'helpers/vue_mock_directive';

import RunnerUpgradeStatusIcon from 'ee/ci/runner/components/runner_upgrade_status_icon.vue';
import {
  UPGRADE_STATUS_AVAILABLE,
  UPGRADE_STATUS_RECOMMENDED,
  UPGRADE_STATUS_NOT_AVAILABLE,
} from 'ee/ci/runner/constants';

describe('RunnerUpgradeStatusIcon', () => {
  let wrapper;
  let glFeatures;

  const findIcon = () => wrapper.findComponent(GlIcon);
  const getTooltipValue = () => getBinding(wrapper.element, 'gl-tooltip').value;

  const createComponent = ({ props = {} } = {}) => {
    wrapper = mount(RunnerUpgradeStatusIcon, {
      propsData: {
        ...props,
      },
      directives: {
        GlTooltip: createMockDirective('gl-tooltip'),
      },
      provide: {
        glFeatures,
      },
    });
  };

  describe('When no feature is enabled', () => {
    beforeEach(() => {
      glFeatures = {};
    });

    it('Displays no upgrade status', () => {
      createComponent();

      expect(findIcon().exists()).toBe(false);
    });
  });

  describe.each([['runnerUpgradeManagement'], ['runnerUpgradeManagementForNamespace']])(
    'When feature "%s" is enabled',
    (feature) => {
      beforeEach(() => {
        glFeatures[feature] = true;
      });

      it('Displays upgrade available icon', () => {
        createComponent({
          props: {
            upgradeStatus: UPGRADE_STATUS_AVAILABLE,
          },
        });

        expect(findIcon().props('name')).toBe('upgrade');
        expect(getTooltipValue()).toBe('An upgrade is available for this runner');
      });

      it('Displays upgrade recommended icon', () => {
        createComponent({
          props: {
            upgradeStatus: UPGRADE_STATUS_RECOMMENDED,
          },
        });

        expect(findIcon().props('name')).toBe('upgrade');
        expect(getTooltipValue()).toBe('An upgrade is recommended for this runner');
      });

      it('Displays no icon', () => {
        createComponent({
          props: {
            upgradeStatus: UPGRADE_STATUS_NOT_AVAILABLE,
          },
        });

        expect(findIcon().exists()).toBe(false);
      });
    },
  );
});
