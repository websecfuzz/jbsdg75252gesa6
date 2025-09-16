import { GlFilteredSearchToken } from '@gitlab/ui';
import { orderBy } from 'lodash';
import Api from '~/api';
import axios from '~/lib/utils/axios_utils';
import { __ } from '~/locale';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import {
  FILTERED_SEARCH_TERM,
  OPERATORS_IS,
  OPERATOR_NOT,
  OPERATOR_IS,
  OPERATORS_IS_NOT,
  OPERATORS_IS_NOT_OR,
  OPERATOR_OR,
  TOKEN_TITLE_AUTHOR,
  TOKEN_TITLE_CONFIDENTIAL,
  TOKEN_TITLE_GROUP,
  TOKEN_TITLE_LABEL,
  TOKEN_TITLE_MILESTONE,
  TOKEN_TITLE_MY_REACTION,
  TOKEN_TYPE_AUTHOR,
  TOKEN_TYPE_CONFIDENTIAL,
  TOKEN_TYPE_CUSTOM_FIELD,
  TOKEN_TYPE_EPIC,
  TOKEN_TYPE_GROUP,
  TOKEN_TYPE_LABEL,
  TOKEN_TYPE_MILESTONE,
  TOKEN_TYPE_MY_REACTION,
  TOKEN_TYPE_SEARCH_WITHIN,
} from '~/vue_shared/components/filtered_search_bar/constants';
import UserToken from '~/vue_shared/components/filtered_search_bar/tokens/user_token.vue';
import EmojiToken from '~/vue_shared/components/filtered_search_bar/tokens/emoji_token.vue';
import GroupToken from '~/vue_shared/components/filtered_search_bar/tokens/group_token.vue';
import LabelToken from '~/vue_shared/components/filtered_search_bar/tokens/label_token.vue';
import MilestoneToken from '~/vue_shared/components/filtered_search_bar/tokens/milestone_token.vue';
import { TOKEN_TITLE_EPIC } from 'ee/vue_shared/components/filtered_search_bar/constants';
import EpicToken from 'ee/vue_shared/components/filtered_search_bar/tokens/epic_token.vue';

const CustomFieldToken = () =>
  import('ee/vue_shared/components/filtered_search_bar/tokens/custom_field_token.vue');

export default {
  inject: ['groupFullPath', 'groupMilestonesPath', 'hasCustomFieldsFeature'],
  computed: {
    urlParams() {
      const {
        in: searchWithin,
        search,
        authorUsername,
        labelName,
        milestoneTitle,
        confidential,
        myReactionEmoji,
        epicIid,
        groupPath,
        'not[authorUsername]': notAuthorUsername,
        'not[myReactionEmoji]': notMyReactionEmoji,
        'not[labelName]': notLabelName,
        'or[labelName]': orLabelName,
        'or[authorUsername]': orAuthorUsername,
        ...otherValues
      } = this.filterParams || {};

      const customFields = {};

      for (const [key, value] of Object.entries(otherValues)) {
        if (this.hasCustomFieldsFeature && this.isCustomField(key)) {
          customFields[key] = value;
        }
      }

      return {
        in: searchWithin,
        state: this.currentState || this.epicsState,
        page: this.currentPage,
        sort: this.sortedBy,
        prev: this.prevPageCursor || undefined,
        next: this.nextPageCursor || undefined,
        layout: 'presetType' in this ? this.presetType : undefined,
        timeframe_range_type: 'timeframeRangeType' in this ? this.timeframeRangeType : undefined,
        author_username: authorUsername,
        'label_name[]': labelName,
        milestone_title: milestoneTitle,
        confidential,
        my_reaction_emoji: myReactionEmoji,
        epic_iid: epicIid,
        group_path: groupPath,
        search,
        'not[author_username]': notAuthorUsername,
        'not[my_reaction_emoji]': notMyReactionEmoji,
        'not[label_name][]': notLabelName,
        'or[label_name][]': orLabelName,
        'or[author_username]': orAuthorUsername,
        progress: 'progressTracking' in this ? this.progressTracking : undefined,
        show_progress:
          'isProgressTrackingActive' in this ? this.isProgressTrackingActive : undefined,
        show_milestones: 'isShowingMilestones' in this ? this.isShowingMilestones : undefined,
        milestones_type: 'milestonesType' in this ? this.milestonesType : undefined,
        show_labels: 'isShowingLabels' in this ? this.isShowingLabels : undefined,
        ...customFields,
      };
    },
  },
  methods: {
    isCustomField(fieldName) {
      return fieldName.startsWith('custom-field[');
    },
    getFilteredSearchTokens({ supportsEpic = true } = {}) {
      let preloadedUsers = [];

      if (gon.current_user_id) {
        preloadedUsers = [
          {
            id: gon.current_user_id,
            name: gon.current_user_fullname,
            username: gon.current_username,
            avatar_url: gon.current_user_avatar_url,
          },
        ];
      }

      const tokens = [
        {
          type: TOKEN_TYPE_AUTHOR,
          icon: 'user',
          title: TOKEN_TITLE_AUTHOR,
          unique: false,
          symbol: '@',
          token: UserToken,
          operators: OPERATORS_IS_NOT_OR,
          recentSuggestionsStorageKey: `${this.groupFullPath}-epics-recent-tokens-author_username`,
          fetchUsers: Api.users.bind(Api),
          defaultUsers: [],
          preloadedUsers,
        },
        {
          type: TOKEN_TYPE_LABEL,
          icon: 'labels',
          title: TOKEN_TITLE_LABEL,
          unique: false,
          symbol: '~',
          token: LabelToken,
          operators: OPERATORS_IS_NOT_OR,
          recentSuggestionsStorageKey: `${this.groupFullPath}-epics-recent-tokens-label_name`,
          fetchLabels: (search = '') => {
            const params = {
              only_group_labels: true,
              include_ancestor_groups: true,
              include_descendant_groups: true,
            };

            if (search) {
              params.search = search;
            }

            return Api.groupLabels(encodeURIComponent(this.groupFullPath), {
              params,
            });
          },
        },
        {
          type: TOKEN_TYPE_MILESTONE,
          icon: 'milestone',
          title: TOKEN_TITLE_MILESTONE,
          unique: true,
          symbol: '%',
          token: MilestoneToken,
          operators: OPERATORS_IS,
          defaultMilestones: [], // TODO: Add support for wildcards once https://gitlab.com/gitlab-org/gitlab/-/issues/356756 is resolved
          fetchMilestones: (search = '') => {
            return axios.get(this.groupMilestonesPath).then(({ data }) => {
              // TODO: Remove below condition check once either of the following is supported.
              // a) Milestones Private API supports search param.
              // b) Milestones Public API supports including child projects' milestones.
              if (search) {
                return {
                  data: data.filter((m) => m.title.toLowerCase().includes(search.toLowerCase())),
                };
              }
              return { data };
            });
          },
        },
        {
          type: TOKEN_TYPE_CONFIDENTIAL,
          icon: 'eye-slash',
          title: TOKEN_TITLE_CONFIDENTIAL,
          unique: true,
          token: GlFilteredSearchToken,
          operators: OPERATORS_IS,
          options: [
            { icon: 'eye-slash', value: true, title: __('Yes') },
            { icon: 'eye', value: false, title: __('No') },
          ],
        },
        {
          type: TOKEN_TYPE_GROUP,
          icon: 'group',
          title: TOKEN_TITLE_GROUP,
          unique: true,
          token: GroupToken,
          operators: OPERATORS_IS,
          fullPath: this.groupFullPath,
        },
      ];

      if (supportsEpic) {
        tokens.push({
          type: TOKEN_TYPE_EPIC,
          icon: 'epic',
          title: TOKEN_TITLE_EPIC,
          unique: true,
          idProperty: 'iid',
          useIdValue: true,
          symbol: '&',
          token: EpicToken,
          operators: OPERATORS_IS,
          recentSuggestionsStorageKey: `${this.groupFullPath}-epics-recent-tokens-epic_iid`,
          fullPath: this.groupFullPath,
        });
      }

      if (gon.current_user_id) {
        // Appending to tokens only when logged-in
        tokens.push({
          type: TOKEN_TYPE_MY_REACTION,
          icon: 'thumb-up',
          title: TOKEN_TITLE_MY_REACTION,
          unique: true,
          token: EmojiToken,
          operators: OPERATORS_IS_NOT,
          fetchEmojis: (search = '') => {
            return axios
              .get(`${gon.relative_url_root || ''}/-/autocomplete/award_emojis`)
              .then(({ data }) => {
                if (search) {
                  return {
                    data: data.filter((e) => e.name.toLowerCase().includes(search.toLowerCase())),
                  };
                }
                return { data };
              });
          },
        });
      }

      if (this.hasCustomFieldsFeature) {
        this.customFields.forEach((field) => {
          tokens.push({
            type: `${TOKEN_TYPE_CUSTOM_FIELD}[${getIdFromGraphQLId(field.id)}]`,
            title: field.name,
            icon: 'multiple-choice',
            field,
            fullPath: this.groupFullPath,
            token: CustomFieldToken,
            operators: OPERATORS_IS,
            unique: true,
          });
        });
      }

      return orderBy(tokens, ['title']);
    },
    getFilteredSearchValue() {
      const {
        in: searchWithin,
        authorUsername,
        labelName,
        milestoneTitle,
        confidential,
        myReactionEmoji,
        search,
        epicIid,
        groupPath,
        'not[authorUsername]': notAuthorUsername,
        'not[myReactionEmoji]': notMyReactionEmoji,
        'not[labelName]': notLabelName,
        'or[labelName]': orLabelName,
        'or[authorUsername]': orAuthorUsername,
        ...otherValues
      } = this.filterParams || {};
      const filteredSearchValue = [];

      for (const [key, value] of Object.entries(otherValues)) {
        if (this.hasCustomFieldsFeature && this.isCustomField(key)) {
          filteredSearchValue.push({
            type: key,
            value: { data: value, operator: OPERATOR_IS },
          });
        }
      }

      if (authorUsername) {
        filteredSearchValue.push({
          type: TOKEN_TYPE_AUTHOR,
          value: { data: authorUsername, operator: OPERATOR_IS },
        });
      }

      if (searchWithin) {
        filteredSearchValue.push({
          type: TOKEN_TYPE_SEARCH_WITHIN,
          value: { data: searchWithin, operator: OPERATOR_IS },
        });
      }

      if (notAuthorUsername) {
        filteredSearchValue.push({
          type: TOKEN_TYPE_AUTHOR,
          value: { data: notAuthorUsername, operator: OPERATOR_NOT },
        });
      }

      if (orAuthorUsername?.length) {
        filteredSearchValue.push({
          type: TOKEN_TYPE_AUTHOR,
          value: { data: orAuthorUsername, operator: OPERATOR_OR },
        });
      }

      if (labelName?.length && Array.isArray(labelName)) {
        filteredSearchValue.push(
          ...labelName.map((label) => ({
            type: TOKEN_TYPE_LABEL,
            value: { data: label, operator: OPERATOR_IS },
          })),
        );
      }
      if (notLabelName?.length) {
        filteredSearchValue.push(
          ...notLabelName.map((label) => ({
            type: TOKEN_TYPE_LABEL,
            value: { data: label, operator: OPERATOR_NOT },
          })),
        );
      }
      if (orLabelName?.length) {
        filteredSearchValue.push(
          ...orLabelName.map((label) => ({
            type: TOKEN_TYPE_LABEL,
            value: { data: label, operator: OPERATOR_OR },
          })),
        );
      }

      if (milestoneTitle) {
        filteredSearchValue.push({
          type: TOKEN_TYPE_MILESTONE,
          value: { data: milestoneTitle },
        });
      }

      if (confidential !== undefined) {
        filteredSearchValue.push({
          type: TOKEN_TYPE_CONFIDENTIAL,
          value: { data: confidential },
        });
      }

      if (myReactionEmoji) {
        filteredSearchValue.push({
          type: TOKEN_TYPE_MY_REACTION,
          value: { data: myReactionEmoji, operator: OPERATOR_IS },
        });
      }
      if (notMyReactionEmoji) {
        filteredSearchValue.push({
          type: TOKEN_TYPE_MY_REACTION,
          value: { data: notMyReactionEmoji, operator: OPERATOR_NOT },
        });
      }

      if (epicIid) {
        filteredSearchValue.push({
          type: TOKEN_TYPE_EPIC,
          value: { data: epicIid },
        });
      }

      if (groupPath) {
        filteredSearchValue.push({
          type: TOKEN_TYPE_GROUP,
          value: { data: groupPath },
        });
      }

      if (search) {
        filteredSearchValue.push(search);
      }

      return filteredSearchValue;
    },
    getFilterParams(filters = []) {
      const filterParams = {};
      const labels = [];
      const orAuthors = [];
      const notLabels = [];
      const orLabels = [];

      filters.forEach((filter) => {
        const { operator, data } = filter.value;
        switch (filter.type) {
          case TOKEN_TYPE_AUTHOR: {
            if (operator === OPERATOR_NOT) {
              filterParams['not[authorUsername]'] = data;
            } else if (operator === OPERATOR_OR) {
              orAuthors.push(data);
            } else {
              filterParams.authorUsername = data;
            }
            break;
          }
          case TOKEN_TYPE_LABEL:
            if (operator === OPERATOR_NOT) {
              notLabels.push(data);
            } else if (operator === OPERATOR_OR) {
              orLabels.push(data);
            } else {
              labels.push(data);
            }
            break;
          case TOKEN_TYPE_MILESTONE:
            filterParams.milestoneTitle = data;
            break;
          case TOKEN_TYPE_CONFIDENTIAL:
            filterParams.confidential = data;
            break;
          case TOKEN_TYPE_MY_REACTION: {
            const key = operator === OPERATOR_NOT ? 'not[myReactionEmoji]' : 'myReactionEmoji';

            filterParams[key] = data;
            break;
          }
          case TOKEN_TYPE_EPIC:
            filterParams.epicIid = data;
            break;
          case TOKEN_TYPE_GROUP:
            filterParams.groupPath = data;
            break;
          case TOKEN_TYPE_SEARCH_WITHIN:
            filterParams.in = data;
            break;
          case FILTERED_SEARCH_TERM:
            if (filter.value.data) {
              filterParams.search = data;
            }
            break;
          default:
            if (this.hasCustomFieldsFeature && this.isCustomField(filter.type)) {
              filterParams[filter.type] = data;
            }
            break;
        }
      });

      if (orAuthors.length) {
        filterParams[`or[authorUsername]`] = orAuthors;
      }

      if (labels.length) {
        filterParams.labelName = labels;
      }

      if (notLabels.length) {
        filterParams[`not[labelName]`] = notLabels;
      }
      if (orLabels.length) {
        filterParams[`or[labelName]`] = orLabels;
      }

      return filterParams;
    },
  },
};
