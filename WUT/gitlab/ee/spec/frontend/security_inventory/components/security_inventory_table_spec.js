import { shallowMount, mount } from '@vue/test-utils';
import { GlTableLite, GlSkeletonLoader } from '@gitlab/ui';
import { stubComponent } from 'helpers/stub_component';
import SecurityInventoryTable from 'ee/security_inventory/components/security_inventory_table.vue';
import NameCell from 'ee/security_inventory/components/name_cell.vue';
import VulnerabilityCell from 'ee/security_inventory/components/vulnerability_cell.vue';
import ToolCoverageCell from 'ee/security_inventory/components/tool_coverage_cell.vue';
import ActionCell from 'ee/security_inventory/components/action_cell.vue';
import { subgroupsAndProjects } from '../mock_data';

const mockProject = subgroupsAndProjects.data.group.projects.nodes[0];
const mockGroup = subgroupsAndProjects.data.group.descendantGroups.nodes[0];
const items = [mockGroup, mockProject];

describe('SecurityInventoryTable', () => {
  let wrapper;

  const createComponentFactory = ({ mountFn = shallowMount } = {}) => {
    return ({ props = {}, stubs = {} } = {}) => {
      wrapper = mountFn(SecurityInventoryTable, {
        propsData: {
          items,
          ...props,
        },
        stubs: {
          GlTableLite: { ...stubComponent(GlTableLite), props: ['items', 'fields'] },
          ...stubs,
        },
      });

      return wrapper;
    };
  };

  const createComponent = createComponentFactory();
  const createFullComponent = createComponentFactory({ mountFn: mount });

  const findTable = () => wrapper.findComponent(GlTableLite);
  const findTableRows = () => findTable().findAll('tbody tr');
  const findNthTableRow = (n) => findTableRows().at(n);

  beforeEach(() => {
    createComponent();
  });

  describe('component rendering', () => {
    it('renders the table component', () => {
      expect(findTable().exists()).toBe(true);
    });

    it('passes fields to GlTableLite component', () => {
      expect(findTable().props('fields')).toEqual([
        { key: 'name', label: 'Name', thClass: 'gl-max-w-0' },
        { key: 'vulnerabilities', label: 'Vulnerabilities', thClass: 'gl-w-1/5' },
        { key: 'toolCoverage', label: 'Tool Coverage', thClass: 'gl-w-1/3' },
        { key: 'actions', label: '', thClass: 'gl-w-2/20' },
      ]);
    });

    it('passes items to GlTableLite component', () => {
      expect(findTable().props('items')).toEqual(items);
    });
  });

  describe('loading state', () => {
    beforeEach(() => {
      createFullComponent({ props: { items: [], isLoading: true }, stubs: { GlTableLite: false } });
    });

    it('shows the correct number of skeleton rows when loading', () => {
      expect(findTableRows()).toHaveLength(3);
    });

    it('shows skeleton loaders for each column in a row', () => {
      const firstRow = findNthTableRow(0);
      const firstRowLoaders = firstRow.findAllComponents(GlSkeletonLoader);
      expect(firstRowLoaders).toHaveLength(4);
    });
  });

  describe('cell rendering', () => {
    beforeEach(() => {
      createFullComponent({ stubs: { GlTableLite: false } });
    });

    it('renders all required cell components', () => {
      expect(findTableRows()).toHaveLength(items.length);

      const firstRow = findNthTableRow(0);
      expect(firstRow.findComponent(NameCell).exists()).toBe(true);
      expect(firstRow.findComponent(VulnerabilityCell).exists()).toBe(true);
      expect(firstRow.findComponent(ToolCoverageCell).exists()).toBe(true);
      expect(firstRow.findComponent(ActionCell).exists()).toBe(true);
    });
  });
});
