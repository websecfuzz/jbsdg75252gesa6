import MockAdapter from 'axios-mock-adapter';
import { nextTick } from 'vue';
import { GlFormInput, GlFormCheckbox } from '@gitlab/ui';
import { GlBreakpointInstance } from '@gitlab/ui/dist/utils';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { createMockDirective, getBinding } from 'helpers/vue_mock_directive';
import waitForPromises from 'helpers/wait_for_promises';
import GroupProjectFields from 'ee/registrations/groups/new/components/group_project_fields.vue';
import ProjectTemplateSelector from 'ee/registrations/groups/new/components/project_template_selector.vue';
import createStore from 'ee/registrations/groups/new/store';
import { DEFAULT_GROUP_PATH, DEFAULT_PROJECT_PATH } from 'ee/registrations/groups/new/constants';
import { createAlert } from '~/alert';
import axios from '~/lib/utils/axios_utils';
import { HTTP_STATUS_INTERNAL_SERVER_ERROR, HTTP_STATUS_OK } from '~/lib/utils/http_status';

jest.mock('~/alert');

describe('GroupProjectFields', () => {
  const initialProps = {
    importGroup: false,
    groupPersisted: false,
    groupId: '',
    groupName: '',
    projectName: '',
    templateName: '',
    initializeWithReadme: false,
    rootUrl: 'https://example.com/',
    trackActionForErrors: '',
  };

  let wrapper;
  let mock;

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(GroupProjectFields, {
      store: createStore(),
      propsData: {
        ...initialProps,
        ...props,
      },
      directives: {
        GlTooltip: createMockDirective('gl-tooltip'),
      },
      stubs: {
        GlFormInput,
      },
    });
  };

  const findInputByTestId = (testId) => wrapper.findByTestId(testId);
  const findProjectTemplateSelector = () => wrapper.findComponent(ProjectTemplateSelector);
  const findCheckbox = () => wrapper.findComponent(GlFormCheckbox);

  const buildUrl = (groupPath = DEFAULT_GROUP_PATH, projectPath = DEFAULT_PROJECT_PATH) =>
    `${initialProps.rootUrl}${groupPath}/${projectPath}`;

  beforeEach(() => {
    mock = new MockAdapter(axios);
  });

  afterEach(() => {
    mock.restore();
  });

  describe('render', () => {
    describe('when create group', () => {
      describe('when new group', () => {
        it('renders inputs', () => {
          createComponent();

          const groupInput = findInputByTestId('group-name');

          expect(groupInput.exists()).toBe(true);
          expect(groupInput.attributes('disabled')).toBe(undefined);

          expect(findInputByTestId('persisted-group-name').exists()).toBe(false);
          expect(findInputByTestId('project-name').exists()).toBe(true);
        });
      });

      describe('when persisted group', () => {
        it('renders inputs', () => {
          createComponent({ groupPersisted: true, groupName: 'group name' });

          const groupInput = findInputByTestId('persisted-group-name');

          expect(groupInput.exists()).toBe(true);
          expect(groupInput.attributes('disabled')).toBeDefined();

          expect(findInputByTestId('group-name').exists()).toBe(false);
          expect(findInputByTestId('project-name').exists()).toBe(true);
        });
      });
    });

    describe('when import group', () => {
      describe('when new group', () => {
        it('renders inputs', () => {
          createComponent({ importGroup: true });

          const groupInput = findInputByTestId('group-name');

          expect(groupInput.exists()).toBe(true);
          expect(groupInput.attributes('disabled')).toBe(undefined);

          expect(findInputByTestId('persisted-group-name').exists()).toBe(false);
          expect(findInputByTestId('project-name').exists()).toBe(false);
        });
      });

      describe('when persisted group', () => {
        it('renders inputs', () => {
          createComponent({
            importGroup: true,
            groupPersisted: true,
            groupName: 'group name',
          });

          const groupInput = findInputByTestId('group-name');

          expect(groupInput.exists()).toBe(true);
          expect(groupInput.attributes('disabled')).toBe(undefined);

          expect(findInputByTestId('persisted-group-name').exists()).toBe(false);
          expect(findInputByTestId('project-name').exists()).toBe(false);
        });
      });
    });
  });

  describe('placement', () => {
    describe('when xs', () => {
      it('places tooltip at the bottom', async () => {
        jest.spyOn(GlBreakpointInstance, 'getBreakpointSize').mockReturnValue('xs');

        window.dispatchEvent(new Event('resize'));
        await nextTick();

        createComponent();
        const tooltip = getBinding(findInputByTestId('group-name').element, 'gl-tooltip');

        expect(tooltip.value.placement).toBe('bottom');
        expect(tooltip.value.title).toBe('Projects are organized into groups');
      });
    });

    describe('when sm', () => {
      it('places tooltip at the right', async () => {
        jest.spyOn(GlBreakpointInstance, 'getBreakpointSize').mockReturnValue('sm');

        window.dispatchEvent(new Event('resize'));
        await nextTick();

        createComponent();
        const tooltip = getBinding(findInputByTestId('group-name').element, 'gl-tooltip');

        expect(tooltip.value.placement).toBe('right');
        expect(tooltip.value.title).toBe('Projects are organized into groups');
      });
    });
  });

  describe('onGroupUpdate', () => {
    it('updates groupName and groupPath', async () => {
      createComponent();

      findInputByTestId('group-name').vm.$emit('update', 'group name');
      await nextTick();

      expect(wrapper.text()).toContain(buildUrl('group-name'));

      findInputByTestId('group-name').vm.$emit('update', '+');
      await nextTick();

      expect(wrapper.text()).toContain(buildUrl());
    });

    describe('suggestions', () => {
      const groupName = 'group name';
      const apiUrl = /namespaces\/group-name\/exists/;

      it('uses suggestion', async () => {
        const suggestion = 'new-group-name';

        mock.onGet(apiUrl).replyOnce(HTTP_STATUS_OK, {
          exists: true,
          suggests: [suggestion],
        });

        createComponent();

        findInputByTestId('group-name').vm.$emit('update', groupName);
        await waitForPromises();

        expect(wrapper.text()).toContain(buildUrl(suggestion));
      });

      describe('when there are no suggestions', () => {
        it('creates alert', async () => {
          mock.onGet(apiUrl).replyOnce(HTTP_STATUS_OK, {
            exists: true,
            suggests: [],
          });

          createComponent();

          findInputByTestId('group-name').vm.$emit('update', groupName);
          await waitForPromises();

          expect(createAlert).toHaveBeenCalledWith({
            message: 'Unable to suggest a path. Please refresh and try again.',
          });
        });
      });

      describe('when suggestions request fails', () => {
        it('creates alert', async () => {
          mock.onGet(apiUrl).replyOnce(HTTP_STATUS_INTERNAL_SERVER_ERROR);

          createComponent();

          findInputByTestId('group-name').vm.$emit('update', groupName);
          await waitForPromises();

          expect(createAlert).toHaveBeenCalledWith({
            message: 'An error occurred while checking group path. Please refresh and try again.',
          });
        });
      });
    });
  });

  describe('onProjectUpdate', () => {
    it('updates projectPath', async () => {
      createComponent();

      findInputByTestId('project-name').vm.$emit('update', 'project name');
      await nextTick();

      expect(wrapper.text()).toContain(buildUrl(DEFAULT_GROUP_PATH, 'project-name'));

      findInputByTestId('project-name').vm.$emit('update', '+');
      await nextTick();

      expect(wrapper.text()).toContain(buildUrl());
    });
  });

  describe('url', () => {
    describe('when create group', () => {
      describe('when new group', () => {
        it('renders url', () => {
          createComponent();

          expect(wrapper.text()).toContain(buildUrl());
        });
      });

      describe('when persisted group', () => {
        it('renders url', async () => {
          createComponent({ groupPersisted: true, groupName: 'group name' });
          await nextTick();

          expect(wrapper.text()).toContain(buildUrl('group-name'));
        });
      });
    });

    describe('when import group', () => {
      it('renders url', () => {
        createComponent({ importGroup: true });

        expect(wrapper.text()).toContain(buildUrl());
      });
    });
  });

  describe('ProjectTemplateSelector', () => {
    it('renders ProjectTemplateSelector', () => {
      createComponent();

      expect(findProjectTemplateSelector().exists()).toBe(true);
    });

    it('passes selected template to ProjectTemplateSelector', () => {
      const templateName = '_template_name_';

      createComponent({ templateName });

      expect(findProjectTemplateSelector().props('selectedTemplateName')).toBe(templateName);
    });

    describe('when import group', () => {
      it('does not render ProjectTemplateSelector', () => {
        createComponent({ importGroup: true });

        expect(findProjectTemplateSelector().exists()).toBe(false);
      });
    });
  });

  describe('readme checkbox', () => {
    describe('when create group', () => {
      describe('when includes readme', () => {
        it('renders checked checkbox', () => {
          createComponent({ initializeWithReadme: true });

          expect(findCheckbox().attributes('checked')).toBe('true');
        });
      });

      describe('when does not include readme', () => {
        it('renders unchecked checkbox', () => {
          createComponent({ initializeWithReadme: false });

          expect(findCheckbox().attributes('checked')).toBe(undefined);
        });
      });

      describe('when project template is selected', () => {
        it('does not render checkbox', () => {
          createComponent({ initializeWithReadme: true, templateName: '_template_name_' });

          expect(findCheckbox().exists()).toBe(false);
        });
      });
    });

    describe('when import group', () => {
      it('does not render checkbox', () => {
        createComponent({ importGroup: true });

        expect(findCheckbox().exists()).toBe(false);
      });
    });
  });

  describe('when form was filled, submitted and failed', () => {
    it('fills inputs and renders url', async () => {
      createComponent({ groupName: '@_', projectName: 'project name' });
      await nextTick();

      expect(findInputByTestId('group-name').props('value')).toBe('@_');
      expect(findInputByTestId('project-name').props('value')).toBe('project name');
      expect(wrapper.text()).toContain(buildUrl('_', 'project-name'));
    });
  });
});
