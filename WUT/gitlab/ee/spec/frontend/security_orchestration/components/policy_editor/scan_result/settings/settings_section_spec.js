import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import {
  BLOCK_BRANCH_MODIFICATION,
  PREVENT_APPROVAL_BY_AUTHOR,
  PREVENT_PUSHING_AND_FORCE_PUSHING,
} from 'ee/security_orchestration/components/policy_editor/scan_result/lib/settings';
import SettingsSection from 'ee/security_orchestration/components/policy_editor/scan_result/settings/settings_section.vue';
import SettingsItem from 'ee/security_orchestration/components/policy_editor/scan_result/settings/settings_item.vue';

describe('SettingsSection', () => {
  let wrapper;

  const createSettings = ({ key, value }) => ({
    [key]: value,
  });

  const createComponent = ({ propsData = {}, provide = {} } = {}) => {
    wrapper = shallowMountExtended(SettingsSection, {
      propsData,
      provide: {
        namespacePath: 'test-path',
        ...provide,
      },
    });
  };

  const findAllSettingsItem = () => wrapper.findAllComponents(SettingsItem);
  const findProtectedBranchesSettingsItem = () =>
    wrapper.findByTestId('protected-branches-setting');
  const findMergeRequestSettingsItem = () => wrapper.findByTestId('merge-request-setting');
  const findEmptyState = () => wrapper.findByTestId('empty-state');

  describe('rendering', () => {
    it('should render the empty message when no settings are provided', () => {
      createComponent();
      expect(findEmptyState().exists()).toBe(true);
    });

    it.each`
      description                                                                               | settings                                                                                                                                              | protectedBranchSettingVisible | mergeRequestSettingVisible
      ${`disable ${BLOCK_BRANCH_MODIFICATION} setting`}                                         | ${createSettings({ key: BLOCK_BRANCH_MODIFICATION, value: false })}                                                                                   | ${true}                       | ${false}
      ${`enable ${BLOCK_BRANCH_MODIFICATION} setting`}                                          | ${createSettings({ key: BLOCK_BRANCH_MODIFICATION, value: true })}                                                                                    | ${true}                       | ${false}
      ${`enable ${PREVENT_PUSHING_AND_FORCE_PUSHING} setting`}                                  | ${createSettings({ key: PREVENT_PUSHING_AND_FORCE_PUSHING, value: true })}                                                                            | ${true}                       | ${false}
      ${`enable ${BLOCK_BRANCH_MODIFICATION} and ${PREVENT_PUSHING_AND_FORCE_PUSHING} setting`} | ${{ ...createSettings({ key: BLOCK_BRANCH_MODIFICATION, value: true }), ...createSettings({ key: PREVENT_PUSHING_AND_FORCE_PUSHING, value: true }) }} | ${true}                       | ${false}
      ${`disable ${PREVENT_APPROVAL_BY_AUTHOR} setting`}                                        | ${createSettings({ key: PREVENT_APPROVAL_BY_AUTHOR, value: false })}                                                                                  | ${false}                      | ${true}
      ${`enable ${PREVENT_APPROVAL_BY_AUTHOR} setting`}                                         | ${createSettings({ key: PREVENT_APPROVAL_BY_AUTHOR, value: true })}                                                                                   | ${false}                      | ${true}
    `('$description', ({ settings, protectedBranchSettingVisible, mergeRequestSettingVisible }) => {
      createComponent({ propsData: { settings } });
      expect(findProtectedBranchesSettingsItem().exists()).toBe(protectedBranchSettingVisible);
      expect(findMergeRequestSettingsItem().exists()).toBe(mergeRequestSettingVisible);
      expect(findAllSettingsItem().at(0).props('settings')).toEqual(settings);
      expect(findEmptyState().exists()).toBe(false);
    });

    it('should render different settings groups', async () => {
      await createComponent({
        propsData: {
          settings: {
            ...createSettings({ key: BLOCK_BRANCH_MODIFICATION, value: true }),
            ...createSettings({ key: PREVENT_APPROVAL_BY_AUTHOR, value: true }),
          },
        },
      });

      expect(findProtectedBranchesSettingsItem().exists()).toBe(true);
      expect(findMergeRequestSettingsItem().exists()).toBe(true);
      expect(findEmptyState().exists()).toBe(false);

      expect(findProtectedBranchesSettingsItem().props('link')).toBe(
        'http://test.host/test-path/-/settings/repository',
      );
      expect(findMergeRequestSettingsItem().props('link')).toBe(
        'http://test.host/test-path/-/settings/merge_requests',
      );
    });
  });

  describe('settings modification', () => {
    it('emits event when setting is toggled', async () => {
      createComponent({
        propsData: { settings: createSettings({ key: BLOCK_BRANCH_MODIFICATION, value: true }) },
      });

      await findAllSettingsItem()
        .at(0)
        .vm.$emit('update', { key: BLOCK_BRANCH_MODIFICATION, value: false });
      expect(wrapper.emitted('changed')).toEqual([
        [createSettings({ key: BLOCK_BRANCH_MODIFICATION, value: false })],
      ]);
    });
  });
});
