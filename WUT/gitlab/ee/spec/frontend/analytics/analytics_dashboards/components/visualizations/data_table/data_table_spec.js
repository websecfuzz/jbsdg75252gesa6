import { GlIcon, GlTableLite, GlKeysetPagination } from '@gitlab/ui';
import { mount, shallowMount } from '@vue/test-utils';
import { extendedWrapper } from 'helpers/vue_test_utils_helper';
import DataTable from 'ee/analytics/analytics_dashboards/components/visualizations/data_table/data_table.vue';
import DiffLineChanges from 'ee/analytics/analytics_dashboards/components/visualizations/data_table/diff_line_changes.vue';

describe('DataTable Visualization', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;

  const findTable = () => wrapper.findComponent(GlTableLite);
  const findTableHeaders = () => findTable().findAll('th');
  const findTableRowCells = (idx) => findTable().find('tbody').findAll('tr').at(idx).findAll('td');
  const findPagination = () => wrapper.findComponent(GlKeysetPagination);

  const nodes = [{ field_one: 'alpha', field_two: 'beta', field_three: 'gamma' }];

  const createWrapper = (mountFn = shallowMount, props = {}) => {
    wrapper = extendedWrapper(
      mountFn(DataTable, {
        propsData: {
          data: { nodes },
          options: {},
          ...props,
        },
        stubs: {
          DiffLineChanges,
        },
      }),
    );
  };

  describe('default behaviour', () => {
    it('should render the table with the expected attributes', () => {
      createWrapper();

      expect(findTable().attributes()).toMatchObject({
        responsive: '',
        hover: '',
      });
    });

    it('should render and style the table headers', () => {
      createWrapper(mount);

      const headers = findTableHeaders();

      expect(headers).toHaveLength(3);

      ['Field One', 'Field Two'].forEach((headerText, idx) => {
        expect(headers.at(idx).text()).toBe(headerText);
      });
    });

    it('should render and style the table cells', () => {
      createWrapper(mount);

      const rowCells = findTableRowCells(0);

      expect(rowCells).toHaveLength(3);

      Object.values(nodes[0]).forEach((value, idx) => {
        expect(rowCells.at(idx).text()).toBe(value);
        expect(rowCells.at(idx).classes()).toEqual(
          expect.arrayContaining(['gl-truncate', 'gl-max-w-0']),
        );
      });
    });

    it('should not add delimiters for small numbers', () => {
      createWrapper(mount, {
        data: {
          nodes: [
            {
              field_one: 123,
            },
          ],
        },
      });

      const rowCells = findTableRowCells(0);

      expect(rowCells.at(0).text()).toBe('123');
    });

    it.each([
      [1234, '1,234'],
      [12345, '12,345'],
      [123456789, '123,456,789'],
    ])('should format "%d" with delimiters as "%s"', (value, expected) => {
      createWrapper(mount, {
        data: {
          nodes: [
            {
              field_one: value,
            },
          ],
        },
      });

      const rowCells = findTableRowCells(0);

      expect(rowCells.at(0).text()).toBe(expected);
    });
  });

  describe('with links data', () => {
    it('should render values as links when provided with links data', () => {
      const linksData = [
        { foo: { text: 'foo', href: 'https://example.com/foo' } },
        { bar: { text: 'bar', href: 'https://example.com/bar' } },
      ];
      createWrapper(mount, { data: { nodes: linksData } });

      const rowCells = findTableRowCells(0);

      Object.values(linksData[0]).forEach((linkConfig, idx) => {
        const link = rowCells.at(idx).find('a');

        expect(link.exists()).toBe(true);
        expect(link.text()).toBe(linkConfig.text);
        expect(link.attributes('href')).toBe(linkConfig.href);
      });
    });

    it('should render external link icon for external links', () => {
      const linksData = [{ foo: { text: 'foo', href: 'https://example.com/foo' } }];
      createWrapper(mount, { data: { nodes: linksData } });

      const rowCells = findTableRowCells(0);

      Object.values(linksData[0]).forEach((linkConfig, idx) => {
        const icon = rowCells.at(idx).find('a').findComponent(GlIcon);

        expect(icon.exists()).toBe(true);
        expect(icon.props('name')).toBe('external-link');
      });
    });

    it('should not add delimiters to link text for small numbers', () => {
      createWrapper(mount, {
        data: {
          nodes: [{ foo: { text: 123, href: 'https://example.com/foo' } }],
        },
      });

      const rowCells = findTableRowCells(0);

      expect(rowCells.at(0).text()).toBe('123');
    });

    it.each([
      [1234, '1,234'],
      [12345, '12,345'],
      [123456789, '123,456,789'],
    ])('should format link text of "%d" with delimiters as "%s"', (value, expected) => {
      createWrapper(mount, {
        data: {
          nodes: [{ foo: { text: value, href: 'https://example.com/foo' } }],
        },
      });

      const rowCells = findTableRowCells(0);

      expect(rowCells.at(0).text()).toBe(expected);
    });

    it('should not allow unsafe URLs to be linkable', () => {
      /* eslint-disable no-script-url */
      const linksData = [
        { foo: { text: 'foo', href: 'https://example.com/foo' } },
        { foo: { text: 'bar', href: 'javascript:alert("XSS")' } },
      ];
      /* eslint-enable no-script-url */

      createWrapper(mount, { data: { nodes: linksData } });

      const badLink = findTableRowCells(1).at(0).find('a');

      expect(findTableRowCells(0).at(0).find('a').exists()).toBe(true);
      expect(badLink.text()).toBe('bar');
      expect(badLink.attributes('href')).toBe('about:blank');
    });
  });

  describe('pagination', () => {
    it('does not render page controls if there is no other pages', () => {
      createWrapper();

      expect(findPagination().exists()).toBe(false);
    });

    describe('with previous page', () => {
      const pageInfo = { hasPreviousPage: true, startCursor: 'start' };

      beforeEach(() => {
        createWrapper(mount, { data: { nodes, pageInfo } });
      });

      it('renders pagination controls', () => {
        expect(findPagination().props()).toMatchObject(pageInfo);
      });

      it('emits updateQuery when selected', () => {
        findPagination().vm.$emit('prev');

        expect(wrapper.emitted('updateQuery')[0][0]).toMatchObject({
          pagination: {
            prevPageCursor: pageInfo.startCursor,
          },
        });
      });
    });

    describe('with next page', () => {
      const pageInfo = { hasNextPage: true, endCursor: 'end' };

      beforeEach(() => {
        createWrapper(mount, { data: { nodes, pageInfo } });
      });

      it('renders pagination controls', () => {
        expect(findPagination().props()).toMatchObject(pageInfo);
      });

      it('emits updateQuery when selected', () => {
        findPagination().vm.$emit('next');

        expect(wrapper.emitted('updateQuery')[0][0]).toMatchObject({
          pagination: {
            nextPageCursor: pageInfo.endCursor,
          },
        });
      });
    });
  });

  describe('options', () => {
    describe('fields', () => {
      it('can specify the fields to render', () => {
        createWrapper(mount, {
          options: {
            fields: [{ key: 'field_three' }, { key: 'field_two' }],
          },
        });

        const rowCells = findTableRowCells(0);
        expect(rowCells).toHaveLength(2);

        const headers = findTableHeaders();
        expect(headers).toHaveLength(2);

        [
          { field: 'Field Three', value: 'gamma' },
          { field: 'Field Two', value: 'beta' },
        ].forEach(({ field, value }, index) => {
          expect(headers.at(index).text()).toBe(field);
          expect(rowCells.at(index).text()).toBe(value);
        });
      });

      it('can customize column labels', () => {
        createWrapper(mount, {
          options: {
            fields: [
              { key: 'field_three', label: 'Power level' },
              { key: 'field_two', label: 'Saiyan level' },
            ],
          },
        });

        const headers = findTableHeaders();
        expect(headers).toHaveLength(2);

        ['Power level', 'Saiyan level'].forEach((field, index) => {
          expect(headers.at(index).text()).toBe(field);
        });
      });

      it('renders a custom component with the correct props', () => {
        const customData = { additions: 10, deletions: 10 };

        createWrapper(mount, {
          data: { nodes: [{ customData }] },
          options: {
            fields: [{ key: 'customData', component: 'DiffLineChanges' }],
          },
        });

        expect(wrapper.findComponent(DiffLineChanges).props()).toMatchObject(customData);
      });
    });
  });
});
