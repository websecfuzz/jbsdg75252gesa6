import { GlTableLite } from '@gitlab/ui';
import { mount } from '@vue/test-utils';
import ReportItem from 'ee/vulnerabilities/components/generic_report/report_item.vue';
import Table from 'ee/vulnerabilities/components/generic_report/types/report_type_table.vue';
import { extendedWrapper } from 'helpers/vue_test_utils_helper';

const TEST_DATA = {
  header: [{ key: 'column_1', type: 'text', value: 'foo ' }],
  rows: [
    {
      column_1: { type: 'url', href: 'bar' },
    },
  ],
};

describe('ee/vulnerabilities/components/generic_report/types/report_type_table.vue', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;

  const createWrapper = () => {
    return extendedWrapper(
      mount(Table, {
        propsData: {
          ...TEST_DATA,
        },
        stubs: {
          'report-item': ReportItem,
        },
      }),
    );
  };

  const findTable = () => wrapper.findComponent(GlTableLite);
  const findTableHead = () => wrapper.find('thead');
  const findTableBody = () => wrapper.find('tbody');

  beforeEach(() => {
    wrapper = createWrapper();
  });

  it('renders a table', () => {
    expect(findTable().exists()).toBe(true);
  });

  it('renders a table header containing the given report type', () => {
    expect(findTableHead().findComponent(ReportItem).props('item')).toMatchObject(
      TEST_DATA.header[0],
    );
  });

  it('renders a table cell containing the given report type', () => {
    expect(findTableBody().findComponent(ReportItem).props('item')).toMatchObject(
      TEST_DATA.rows[0].column_1,
    );
  });
});
