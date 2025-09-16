import Vue, { nextTick } from 'vue';
import { GlLink } from '@gitlab/ui';
import VueApollo from 'vue-apollo';
import { shallowMount } from '@vue/test-utils';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import WorkItemSidebarDropdownWidget from '~/work_items/components/shared/work_item_sidebar_dropdown_widget.vue';
import WorkItemCustomFieldsMultiSelect from 'ee/work_items/components/work_item_custom_fields_multi_select.vue';
import { newWorkItemId } from '~/work_items/utils';
import { CUSTOM_FIELDS_TYPE_MULTI_SELECT, CUSTOM_FIELDS_TYPE_NUMBER } from '~/work_items/constants';
import updateWorkItemCustomFieldsMutation from 'ee/work_items/graphql/update_work_item_custom_fields.mutation.graphql';
import customFieldSelectOptionsQuery from 'ee/work_items/graphql/work_item_custom_field_select_options.query.graphql';
import { customFieldsWidgetResponseFactory } from 'jest/work_items/mock_data';

describe('WorkItemCustomFieldsMultiSelect', () => {
  let wrapper;

  Vue.use(VueApollo);

  const defaultWorkItemType = 'Issue';
  const defaultWorkItemId = 'gid://gitlab/WorkItem/1';

  const defaultField = {
    customField: {
      id: 'gid://gitlab/Issuables::CustomField/1',
      fieldType: CUSTOM_FIELDS_TYPE_MULTI_SELECT,
      name: 'Multi select custom field label',
    },
    selectedOptions: [
      {
        id: 'gid://gitlab/Issuables::CustomFieldSelectOption/1',
        value: 'Option 1',
      },
      {
        id: 'gid://gitlab/Issuables::CustomFieldSelectOption/2',
        value: 'Option 2',
      },
    ],
  };

  const querySuccessHandler = jest.fn().mockResolvedValue({
    data: {
      customField: {
        id: '1-select',
        selectOptions: [
          {
            id: 'gid://gitlab/Issuables::CustomFieldSelectOption/1',
            value: 'Option 1',
            __typename: 'CustomFieldSelectOption',
          },
          {
            id: 'gid://gitlab/Issuables::CustomFieldSelectOption/2',
            value: 'Option 2',
            __typename: 'CustomFieldSelectOption',
          },
          {
            id: 'gid://gitlab/Issuables::CustomFieldSelectOption/3',
            value: 'Option 3',
            __typename: 'CustomFieldSelectOption',
          },
        ],
        __typename: 'CustomField',
      },
    },
  });

  const mutationSuccessHandler = jest.fn().mockResolvedValue({
    data: {
      workItemUpdate: {
        workItem: {
          id: defaultWorkItemId,
          widgets: [customFieldsWidgetResponseFactory],
        },
        errors: [],
      },
    },
  });

  const findComponent = () => wrapper.findComponent(WorkItemCustomFieldsMultiSelect);
  const findSidebarDropdownWidget = () => wrapper.findComponent(WorkItemSidebarDropdownWidget);
  const findSelectValues = () => wrapper.findAllComponents(GlLink);

  const createComponent = ({
    canUpdate = true,
    workItemType = defaultWorkItemType,
    customField = defaultField,
    workItemId = defaultWorkItemId,
    queryHandler = querySuccessHandler,
    mutationHandler = mutationSuccessHandler,
    issuesListPath = '/flightjs/Flight/-/issues',
  } = {}) => {
    wrapper = shallowMount(WorkItemCustomFieldsMultiSelect, {
      apolloProvider: createMockApollo([
        [customFieldSelectOptionsQuery, queryHandler],
        [updateWorkItemCustomFieldsMutation, mutationHandler],
      ]),
      provide: {
        issuesListPath,
      },
      propsData: {
        canUpdate,
        customField,
        workItemType,
        workItemId,
        fullPath: 'flightjs/FlightJs',
      },
    });
  };

  describe('rendering', () => {
    it('renders if custom field exists and type is correct', async () => {
      createComponent();

      await nextTick();

      expect(findComponent().exists()).toBe(true);
      expect(findSidebarDropdownWidget().exists()).toBe(true);
    });

    it('does not render if custom field is empty', async () => {
      createComponent({ customField: {} });

      await nextTick();

      expect(findComponent().exists()).toBe(true);
      expect(findSidebarDropdownWidget().exists()).toBe(false);
    });

    it('does not render if custom field type is incorrect', async () => {
      createComponent({
        customField: {
          customField: {
            id: '1-number',
            fieldType: CUSTOM_FIELDS_TYPE_NUMBER,
            name: 'Number custom field label',
          },
          selectedOptions: {
            id: 'number',
            value: 3,
          },
        },
      });

      await nextTick();

      expect(findComponent().exists()).toBe(true);
      expect(findSidebarDropdownWidget().exists()).toBe(false);
    });
  });

  it('displays correct label', () => {
    createComponent();

    expect(findSidebarDropdownWidget().props('dropdownLabel')).toBe(
      'Multi select custom field label',
    );
  });

  describe('value', () => {
    it('shows None when no option is set', () => {
      createComponent({
        customField: {
          customField: {
            id: '1-select',
            fieldType: CUSTOM_FIELDS_TYPE_MULTI_SELECT,
            name: 'Multi select custom field label',
          },
          selectedOptions: null,
        },
      });

      expect(findSidebarDropdownWidget().props().toggleDropdownText).toContain('None');
    });

    it('shows None when invalid value is received', () => {
      createComponent({
        customField: {
          customField: {
            id: '1-select',
            fieldType: CUSTOM_FIELDS_TYPE_MULTI_SELECT,
            name: 'Multi select custom field label',
          },
          selectedOptions: 'Sample text',
        },
      });

      expect(findSidebarDropdownWidget().props().toggleDropdownText).toContain('None');
    });

    it('shows option selected on render when it is defined', () => {
      createComponent();

      expect(findSelectValues().at(0).attributes('title')).toBe('Option 1');
      expect(findSelectValues().at(1).attributes('title')).toBe('Option 2');
    });

    it('generates correct search path for project/issues list for each option link when on the project path', () => {
      createComponent();

      expect(findSelectValues().at(0).attributes('href')).toBe(
        '/flightjs/Flight/-/issues/?custom-field[1]=1',
      );
      expect(findSelectValues().at(1).attributes('href')).toBe(
        '/flightjs/Flight/-/issues/?custom-field[1]=2',
      );
    });

    it('generates correct search path for group/issues list for each option link when it is an issue on the group path', () => {
      createComponent({ issuesListPath: '/groups/flightjs/-/issues' });

      expect(findSelectValues().at(0).attributes('href')).toBe(
        '/groups/flightjs/-/issues/?custom-field[1]=1',
      );
      expect(findSelectValues().at(1).attributes('href')).toBe(
        '/groups/flightjs/-/issues/?custom-field[1]=2',
      );
    });

    it('generates correct search path for group/epics list for each option link when it is an epic', () => {
      createComponent({ issuesListPath: '/groups/flightjs/-/epics' });

      expect(findSelectValues().at(0).attributes('href')).toBe(
        '/groups/flightjs/-/epics/?custom-field[1]=1',
      );
      expect(findSelectValues().at(1).attributes('href')).toBe(
        '/groups/flightjs/-/epics/?custom-field[1]=2',
      );
    });
  });

  describe('Dropdown options', () => {
    it('fetches options when dropdown is shown', async () => {
      createComponent();

      expect(querySuccessHandler).not.toHaveBeenCalled();

      await findSidebarDropdownWidget().vm.$emit('dropdownShown');

      expect(querySuccessHandler).toHaveBeenCalled();
    });

    it('shows dropdown options on list according to their state', async () => {
      createComponent();

      findSidebarDropdownWidget().vm.$emit('dropdownShown');
      await waitForPromises();

      expect(findSidebarDropdownWidget().props('toggleDropdownText')).toBe('Option 1, Option 2');
      expect(findSidebarDropdownWidget().props('listItems')).toEqual([
        {
          options: [
            { text: 'Option 1', value: 'gid://gitlab/Issuables::CustomFieldSelectOption/1' },
            { text: 'Option 2', value: 'gid://gitlab/Issuables::CustomFieldSelectOption/2' },
          ],
          text: 'Selected',
        },
        {
          options: [
            { text: 'Option 3', value: 'gid://gitlab/Issuables::CustomFieldSelectOption/3' },
          ],
          text: 'All',
          textSrOnly: true,
        },
      ]);
    });

    it('shows "None" on value when dropdown is open and no option was selected', async () => {
      createComponent({
        customField: {
          customField: {
            id: '1-select',
            fieldType: CUSTOM_FIELDS_TYPE_MULTI_SELECT,
            name: 'Multi select custom field label',
          },
          selectedOptions: null,
        },
      });

      findSidebarDropdownWidget().vm.$emit('dropdownShown');
      await waitForPromises();

      expect(findSidebarDropdownWidget().props('toggleDropdownText')).toBe('None');
      expect(findSidebarDropdownWidget().props('listItems')).toEqual([
        { text: 'Option 1', value: 'gid://gitlab/Issuables::CustomFieldSelectOption/1' },
        { text: 'Option 2', value: 'gid://gitlab/Issuables::CustomFieldSelectOption/2' },
        { text: 'Option 3', value: 'gid://gitlab/Issuables::CustomFieldSelectOption/3' },
      ]);
    });

    it('shows alert error when fetching options fails', async () => {
      const errorQueryHandler = jest.fn().mockRejectedValue(new Error('Network error'));

      createComponent({ queryHandler: errorQueryHandler });

      findSidebarDropdownWidget().vm.$emit('dropdownShown');
      await waitForPromises();

      expect(wrapper.emitted('error')).toEqual([
        [
          'Options could not be loaded for field: Multi select custom field label. Please try again.',
        ],
      ]);
    });
  });

  describe('updating the selection', () => {
    it('does not call "workItemUpdate" mutation when option is selected if is create flow', async () => {
      createComponent({ workItemId: newWorkItemId(defaultWorkItemType) });
      await nextTick();

      findSidebarDropdownWidget().vm.$emit(
        'updateValue',
        'gid://gitlab/Issuables::CustomFieldSelectOption/2',
      );
      await nextTick();

      expect(mutationSuccessHandler).not.toHaveBeenCalled();
    });

    it('sends mutation with correct variables when selecting an option', async () => {
      createComponent();
      await nextTick();

      const newSelectedIds = [
        'gid://gitlab/Issuables::CustomFieldSelectOption/1',
        'gid://gitlab/Issuables::CustomFieldSelectOption/2',
      ];
      findSidebarDropdownWidget().vm.$emit('updateValue', newSelectedIds);

      expect(mutationSuccessHandler).toHaveBeenCalledWith({
        input: {
          id: defaultWorkItemId,
          customFieldsWidget: [
            {
              customFieldId: defaultField.customField.id,
              selectedOptionIds: newSelectedIds,
            },
          ],
        },
      });
    });

    it('sends null when clearing the selection', async () => {
      createComponent();
      await nextTick();

      findSidebarDropdownWidget().vm.$emit('updateValue', []);

      expect(mutationSuccessHandler).toHaveBeenCalledWith({
        input: {
          id: defaultWorkItemId,
          customFieldsWidget: [
            {
              customFieldId: defaultField.customField.id,
              selectedOptionIds: [],
            },
          ],
        },
      });
    });

    it('shows loading state while updating', async () => {
      const mutationHandler = jest.fn().mockImplementation(() => new Promise(() => {}));

      createComponent({ mutationHandler });
      await nextTick();

      findSidebarDropdownWidget().vm.$emit('updateValue', [
        'gid://gitlab/Issuables::CustomFieldSelectOption/1',
        'gid://gitlab/Issuables::CustomFieldSelectOption/2',
      ]);
      await nextTick();

      expect(findSidebarDropdownWidget().props('updateInProgress')).toBe(true);
    });

    it('emits error event when mutation returns an error', async () => {
      jest.spyOn(Sentry, 'captureException');

      const errorMessage = 'Failed to update';
      const mutationHandler = jest.fn().mockResolvedValue({
        data: {
          workItemUpdate: {
            errors: [errorMessage],
          },
        },
      });

      createComponent({ mutationHandler });
      await nextTick();

      findSidebarDropdownWidget().vm.$emit('updateValue', [
        'gid://gitlab/Issuables::CustomFieldSelectOption/1',
        'gid://gitlab/Issuables::CustomFieldSelectOption/2',
      ]);
      await waitForPromises();

      expect(wrapper.emitted('error')).toEqual([
        ['Something went wrong while updating the issue. Please try again.'],
      ]);
      expect(Sentry.captureException).toHaveBeenCalled();
    });

    it('emits error event when mutation catches error', async () => {
      jest.spyOn(Sentry, 'captureException');

      const errorHandler = jest.fn().mockRejectedValue(new Error());

      createComponent({ mutationHandler: errorHandler });
      await nextTick();

      findSidebarDropdownWidget().vm.$emit('updateValue', [
        'gid://gitlab/Issuables::CustomFieldSelectOption/1',
        'gid://gitlab/Issuables::CustomFieldSelectOption/2',
      ]);
      await waitForPromises();

      expect(wrapper.emitted('error')).toEqual([
        ['Something went wrong while updating the issue. Please try again.'],
      ]);
      expect(Sentry.captureException).toHaveBeenCalled();
    });
  });
});
