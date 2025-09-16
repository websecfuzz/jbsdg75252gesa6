import { GlTableLite, GlIcon, GlAvatarsInline, GlKeysetPagination } from '@gitlab/ui';
import { mount } from '@vue/test-utils';
import ThroughputTable from 'ee/analytics/analytics_dashboards/components/visualizations/merge_requests/throughput_table.vue';
import {
  THROUGHPUT_TABLE_TEST_IDS as TEST_IDS,
  INITIAL_PAGINATION_STATE,
  PER_PAGE,
} from 'ee/analytics/merge_request_analytics/constants';
import {
  throughputTableData as list,
  fullPath,
  throughputTableHeaders,
  pageInfo,
} from 'ee_jest/analytics/merge_request_analytics/mock_data';

describe('ThroughputTable Visualization', () => {
  let wrapper;

  const defaultProps = {
    data: {
      list,
      pageInfo: {
        ...INITIAL_PAGINATION_STATE,
        ...pageInfo,
      },
    },
  };

  function createComponent({ props = {} } = {}) {
    wrapper = mount(ThroughputTable, {
      provide: {
        fullPath,
      },
      propsData: {
        data: {
          ...defaultProps.data,
          ...props.data,
        },
      },
      stubs: { GlKeysetPagination },
    });
  }

  const createComponentWithAdditionalData = (additionalData) => {
    createComponent({
      func: mount,
      props: {
        data: {
          list: [{ ...list[0], ...additionalData }],
        },
      },
    });
  };

  const findTable = () => wrapper.findComponent(GlTableLite);

  const findCol = (testId) => findTable().find(`[data-testid="${testId}"]`);

  const findColSubItem = (colTestId, childTetestId) =>
    findCol(colTestId).find(`[data-testid="${childTetestId}"]`);

  const findColSubComponent = (colTestId, childComponent) =>
    findCol(colTestId).findComponent(childComponent);

  const findPagination = () => wrapper.findComponent(GlKeysetPagination);

  describe('default state', () => {
    beforeEach(() => {
      createComponent();
    });

    it('displays the table', () => {
      expect(wrapper.findComponent(GlTableLite).exists()).toBe(true);
    });
  });

  describe('table fields', () => {
    beforeEach(() => {
      createComponent({ func: mount });
    });

    it('displays the correct table headers', () => {
      const headers = findTable().findAll(`[data-testid="${TEST_IDS.TABLE_HEADERS}"]`);

      expect(headers).toHaveLength(throughputTableHeaders.length);

      throughputTableHeaders.forEach((headerText, i) =>
        expect(headers.at(i).text()).toEqual(headerText),
      );
    });

    it('displays the correct date merged', () => {
      expect(findCol(TEST_IDS.DATE_MERGED).text()).toBe('2020-08-06');
    });

    it('displays the correct time to merge', () => {
      expect(findCol(TEST_IDS.TIME_TO_MERGE).text()).toBe('4 minutes');
    });

    it('does not display a milestone if not present', () => {
      expect(findCol(TEST_IDS.MILESTONE).exists()).toBe(false);
    });

    it('displays the correct milestone when available', () => {
      const title = 'v1.0';

      createComponentWithAdditionalData({
        milestone: { id: '1', title },
      });

      expect(findCol(TEST_IDS.MILESTONE).text()).toBe(title);
    });

    it('displays the correct commit count', () => {
      expect(findCol(TEST_IDS.COMMITS).text()).toBe('1');
    });

    it('displays the correct pipeline count', () => {
      expect(findCol(TEST_IDS.PIPELINES).text()).toBe('0');
    });

    it('displays the correctly formatted line changes', () => {
      expect(findCol(TEST_IDS.LINE_CHANGES).text()).toBe('+2 -1');
    });

    it('displays the correct assignees data', () => {
      const assignees = findColSubComponent(TEST_IDS.ASSIGNEES, GlAvatarsInline);

      expect(assignees.exists()).toBe(true);
      expect(assignees.props('avatars')).toEqual(list[0].assignees.nodes);
    });

    describe('merge request details', () => {
      it('includes the correct title and IID', () => {
        const { title, iid } = list[0];

        expect(findCol(TEST_IDS.MERGE_REQUEST_DETAILS).text()).toContain(`${title} !${iid}`);
      });

      it('includes an inactive label icon by default', () => {
        const labels = findColSubItem(TEST_IDS.MERGE_REQUEST_DETAILS, TEST_IDS.LABEL_DETAILS);
        const icon = labels.findComponent(GlIcon);

        expect(labels.text()).toBe('0');
        expect(labels.classes()).toContain('gl-opacity-5');
        expect(icon.exists()).toBe(true);
        expect(icon.props('name')).toBe('label');
      });

      it('includes an inactive comment icon by default', () => {
        const commentCount = findColSubItem(TEST_IDS.MERGE_REQUEST_DETAILS, TEST_IDS.COMMENT_COUNT);
        const icon = commentCount.findComponent(GlIcon);

        expect(commentCount.text()).toBe('0');
        expect(commentCount.classes()).toContain('gl-opacity-5');
        expect(icon.exists()).toBe(true);
        expect(icon.props('name')).toBe('comments');
      });

      it('includes an active label icon and count when available', () => {
        createComponentWithAdditionalData({ labels: { count: 1 } });

        const labelDetails = findColSubItem(TEST_IDS.MERGE_REQUEST_DETAILS, TEST_IDS.LABEL_DETAILS);
        const icon = labelDetails.findComponent(GlIcon);

        expect(labelDetails.text()).toBe('1');
        expect(labelDetails.classes()).not.toContain('gl-opacity-5');
        expect(icon.exists()).toBe(true);
        expect(icon.props('name')).toBe('label');
      });

      it('includes an active comment icon and count when available', () => {
        createComponentWithAdditionalData({
          userNotesCount: 2,
        });

        const commentCount = findColSubItem(TEST_IDS.MERGE_REQUEST_DETAILS, TEST_IDS.COMMENT_COUNT);
        const icon = commentCount.findComponent(GlIcon);

        expect(commentCount.text()).toBe('2');
        expect(commentCount.classes()).not.toContain('gl-opacity-5');
        expect(icon.exists()).toBe(true);
        expect(icon.props('name')).toBe('comments');
      });

      it('includes a pipeline icon when available', () => {
        const iconName = 'status_canceled';

        createComponentWithAdditionalData({
          pipelines: {
            nodes: [
              {
                id: '1',
                detailedStatus: {
                  id: '1',
                  icon: iconName,
                },
              },
            ],
          },
        });

        const icon = findColSubComponent(TEST_IDS.MERGE_REQUEST_DETAILS, GlIcon);

        expect(icon.findComponent(GlIcon).exists()).toBe(true);
        expect(icon.props('name')).toBe(iconName);
      });
    });

    describe('approval details', () => {
      const iconName = 'approval';

      it('does not display by default', () => {
        const approved = findColSubItem(TEST_IDS.MERGE_REQUEST_DETAILS, TEST_IDS.APPROVED);

        expect(approved.exists()).toBe(false);
      });

      it('displays the singular when there is a single approval', () => {
        createComponentWithAdditionalData({
          approvedBy: {
            nodes: [
              {
                id: 1,
              },
            ],
          },
        });

        const approved = findColSubItem(TEST_IDS.MERGE_REQUEST_DETAILS, TEST_IDS.APPROVED);
        const icon = approved.findComponent(GlIcon);

        expect(approved.text()).toBe('1 Approval');
        expect(icon.exists()).toBe(true);
        expect(icon.props('name')).toBe(iconName);
      });

      it('displays the plural when there are multiple approvals', () => {
        createComponentWithAdditionalData({
          approvedBy: {
            nodes: [
              {
                id: 1,
              },
              {
                id: 2,
              },
            ],
          },
        });

        const approved = findColSubItem(TEST_IDS.MERGE_REQUEST_DETAILS, TEST_IDS.APPROVED);
        const icon = approved.findComponent(GlIcon);

        expect(approved.text()).toBe('2 Approvals');
        expect(icon.exists()).toBe(true);
        expect(icon.props('name')).toBe(iconName);
      });
    });
  });

  describe('pagination', () => {
    const createComponentWithPagination = (data = {}) => {
      createComponent({
        props: {
          data: {
            list,
            pageInfo: {
              currentPage: 1,
              ...data,
            },
          },
        },
      });
    };

    it('displays the pagination', () => {
      createComponentWithPagination({ hasPreviousPage: true, hasNextPage: true });

      expect(findPagination().exists()).toBe(true);
    });

    it('disables the prev button on the first page', () => {
      createComponentWithPagination({ hasNextPage: true });

      expect(findPagination().props().hasNextPage).toBe(true);
      expect(findPagination().props().hasPreviousPage).toBe(false);
    });

    it('disables the next button on the last page', () => {
      createComponentWithPagination({ hasPreviousPage: true });

      expect(findPagination().props().hasPreviousPage).toBe(true);
      expect(findPagination().props().hasNextPage).toBe(false);
    });

    it.each`
      eventName | pagination
      ${'prev'} | ${{ lastPageSize: PER_PAGE, prevPageCursor: 'start-cursor' }}
      ${'next'} | ${{ firstPageSize: PER_PAGE, nextPageCursor: 'end-cursor' }}
    `(
      'emits the updateQuery event when the "$eventName" event is triggered',
      ({ eventName, pagination }) => {
        createComponentWithPagination({
          startCursor: 'start-cursor',
          endCursor: 'end-cursor',
          hasPreviousPage: true,
          hasNextPage: true,
        });

        findPagination().vm.$emit(eventName);

        expect(wrapper.emitted('updateQuery')).toBeDefined();
        expect(wrapper.emitted('updateQuery')[0][0]).toEqual({ pagination });
      },
    );
  });
});
