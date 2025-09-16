<script>
import emptyStateSvg from '@gitlab/svgs/dist/illustrations/empty-state/empty-epic-md.svg';
import { GlEmptyState } from '@gitlab/ui';
import { createAlert } from '~/alert';
import { s__ } from '~/locale';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import EmptyStateWithAnyIssues from '~/issues/list/components/empty_state_with_any_issues.vue';
import {
  WORK_ITEM_TYPE_NAME_EPIC,
  WORK_ITEM_TYPE_NAME_ISSUE,
  CUSTOM_FIELDS_TYPE_MULTI_SELECT,
  CUSTOM_FIELDS_TYPE_SINGLE_SELECT,
} from '~/work_items/constants';
import {
  TOKEN_TYPE_CUSTOM_FIELD,
  OPERATORS_IS,
} from '~/vue_shared/components/filtered_search_bar/constants';
import WorkItemsListApp from '~/work_items/pages/work_items_list_app.vue';
import CreateWorkItemModal from '~/work_items/components/create_work_item_modal.vue';

import namespaceCustomFieldsQuery from 'ee/vue_shared/components/filtered_search_bar/queries/custom_field_names.query.graphql';

const CustomFieldToken = () =>
  import('ee/vue_shared/components/filtered_search_bar/tokens/custom_field_token.vue');

export default {
  emptyStateSvg,
  WORK_ITEM_TYPE_NAME_EPIC,
  components: {
    CreateWorkItemModal,
    EmptyStateWithAnyIssues,
    GlEmptyState,
    WorkItemsListApp,
  },
  inject: [
    'hasEpicsFeature',
    'isGroup',
    'showNewWorkItem',
    'workItemType',
    'hasCustomFieldsFeature',
  ],
  props: {
    withTabs: {
      type: Boolean,
      required: false,
      default: true,
    },
    newCommentTemplatePaths: {
      type: Array,
      required: false,
      default: () => [],
    },
    rootPageFullPath: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      workItemUpdateCount: 0,
      customFields: [],
    };
  },
  apollo: {
    customFields: {
      query: namespaceCustomFieldsQuery,
      variables() {
        return {
          fullPath: this.rootPageFullPath,
          active: true,
        };
      },
      skip() {
        return !this.hasCustomFieldsFeature;
      },
      update(data) {
        return (data.namespace?.customFields?.nodes || []).filter((field) => {
          const fieldTypeAllowed = [
            CUSTOM_FIELDS_TYPE_SINGLE_SELECT,
            CUSTOM_FIELDS_TYPE_MULTI_SELECT,
          ].includes(field.fieldType);
          const fieldAllowedOnWorkItem = field.workItemTypes.some(
            (type) => type.name === this.workItemType,
          );

          return fieldTypeAllowed && fieldAllowedOnWorkItem;
        });
      },
      error(error) {
        createAlert({
          message: s__('WorkItem|Failed to load custom fields.'),
          captureError: true,
          error,
        });
      },
    },
  },
  computed: {
    preselectedWorkItemType() {
      return this.isEpicsList ? WORK_ITEM_TYPE_NAME_EPIC : WORK_ITEM_TYPE_NAME_ISSUE;
    },
    isEpicsList() {
      return this.workItemType === WORK_ITEM_TYPE_NAME_EPIC;
    },
    searchTokens() {
      const tokens = [];

      if (this.customFields.length > 0) {
        this.customFields.forEach((field) => {
          tokens.push({
            type: `${TOKEN_TYPE_CUSTOM_FIELD}[${getIdFromGraphQLId(field.id)}]`,
            title: field.name,
            icon: 'multiple-choice',
            field,
            fullPath: this.rootPageFullPath,
            token: CustomFieldToken,
            operators: OPERATORS_IS,
            unique: field.fieldType !== CUSTOM_FIELDS_TYPE_MULTI_SELECT,
          });
        });
      }

      return tokens;
    },
  },
  methods: {
    incrementUpdateCount() {
      this.workItemUpdateCount += 1;
    },
  },
};
</script>

<template>
  <work-items-list-app
    :ee-work-item-update-count="workItemUpdateCount"
    :ee-search-tokens="searchTokens"
    :root-page-full-path="rootPageFullPath"
    :with-tabs="withTabs"
    :new-comment-template-paths="newCommentTemplatePaths"
  >
    <template v-if="isEpicsList && hasEpicsFeature" #list-empty-state="{ hasSearch, isOpenTab }">
      <empty-state-with-any-issues
        :has-search="hasSearch"
        :is-epic="isEpicsList"
        :is-open-tab="isOpenTab"
      >
        <template v-if="showNewWorkItem" #new-issue-button>
          <create-work-item-modal
            class="gl-grow"
            :full-path="rootPageFullPath"
            :is-group="isGroup"
            :preselected-work-item-type="preselectedWorkItemType"
            @workItemCreated="incrementUpdateCount"
          />
        </template>
      </empty-state-with-any-issues>
    </template>
    <template v-if="isEpicsList && hasEpicsFeature" #page-empty-state>
      <gl-empty-state
        :description="
          __('Track groups of issues that share a theme, across projects and milestones')
        "
        :svg-path="$options.emptyStateSvg"
        :title="
          __(
            'Epics let you manage your portfolio of projects more efficiently and with less effort',
          )
        "
      >
        <template v-if="showNewWorkItem" #actions>
          <create-work-item-modal
            class="gl-grow"
            :full-path="rootPageFullPath"
            :is-group="isGroup"
            :preselected-work-item-type="$options.WORK_ITEM_TYPE_NAME_EPIC"
            @workItemCreated="incrementUpdateCount"
          />
        </template>
      </gl-empty-state>
    </template>
  </work-items-list-app>
</template>
