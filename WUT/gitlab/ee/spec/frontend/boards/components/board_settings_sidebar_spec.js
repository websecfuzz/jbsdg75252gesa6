import { GlLabel } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import BoardSettingsListTypes from 'ee_component/boards/components/board_settings_list_types.vue';
import BoardSettingsWipLimit from 'ee_component/boards/components/board_settings_wip_limit.vue';
import { mockLabelList, mockMilestoneList } from 'jest/boards/mock_data';
import BoardSettingsSidebar from '~/boards/components/board_settings_sidebar.vue';

describe('ee/BoardSettingsSidebar', () => {
  let wrapper;

  const createComponent = ({ isWipLimitsOn = false, list = {}, provide = {} } = {}) => {
    wrapper = shallowMount(BoardSettingsSidebar, {
      provide: {
        glFeatures: {
          wipLimits: isWipLimitsOn,
        },
        canAdminList: false,
        scopedLabelsAvailable: true,
        isIssueBoard: true,
        boardType: 'group',
        issuableType: 'issue',
        ...provide,
      },
      propsData: {
        listId: list.id,
        boardId: 'gid://gitlab/Board/1',
        list,
        queryVariables: {},
      },
      stubs: {
        'board-settings-sidebar-wip-limit': BoardSettingsWipLimit,
        'board-settings-list-types': BoardSettingsListTypes,
      },
    });
  };

  it('confirms we render BoardSettingsSidebarWipLimit', () => {
    createComponent({ list: mockLabelList, isWipLimitsOn: true });

    expect(wrapper.findComponent(BoardSettingsWipLimit).exists()).toBe(true);
  });

  it('confirms we render BoardSettingsListTypes', () => {
    createComponent({ list: mockMilestoneList });

    expect(wrapper.findComponent(BoardSettingsListTypes).exists()).toBe(true);
  });

  it('passes scoped prop to label when label is scoped', () => {
    createComponent({
      list: { ...mockLabelList, label: { ...mockLabelList.label, title: 'foo::bar' } },
    });

    expect(wrapper.findComponent(GlLabel).props('scoped')).toBe(true);
  });
});
