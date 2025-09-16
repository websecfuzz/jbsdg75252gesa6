import { GlCollapse, GlButton } from '@gitlab/ui';
import EditSection from 'ee/compliance_dashboard/components/frameworks_report/edit_framework/components/edit_section.vue';
import { mountExtended } from 'helpers/vue_test_utils_helper';

describe('Section', () => {
  let wrapper;

  const title = 'Foo';
  const description = 'Bar';
  const itemsCount = 10;

  const findTitle = () => wrapper.findByText(title);
  const findDescription = () => wrapper.findByText(description);
  const findCollapse = () => wrapper.findComponent(GlCollapse);
  const findCollapseButton = () => wrapper.findComponent(GlButton);
  const findCountBadge = () => wrapper.findByTestId('count-badge');
  const findStatusBadge = () => wrapper.findByTestId('status-badge');

  const createComponent = (propsData = {}) => {
    wrapper = mountExtended(EditSection, {
      propsData: {
        title,
        description,
        ...propsData,
      },
    });
  };

  it('renders title', () => {
    createComponent();
    expect(findTitle().exists()).toBe(true);
  });

  it('renders description', () => {
    createComponent();
    expect(findDescription().exists()).toBe(true);
  });

  describe('count badge rendering', () => {
    it('does not render count badge by default', () => {
      createComponent();
      expect(findCountBadge().exists()).toBe(false);
    });

    it('renders count badge with number when itemsCount is provided', () => {
      createComponent({ itemsCount });
      expect(findCountBadge().text()).toBe('10');
    });
  });

  describe('status badge rendering', () => {
    it('does not render status badge as optional by  default', () => {
      createComponent();
      expect(findStatusBadge().text()).toBe('Optional');
    });

    it('does not render status badge as required when isRequired prop is true', () => {
      createComponent({ isRequired: true });
      expect(findStatusBadge().text()).toBe('Required');
    });

    it('does not render icon by default', () => {
      createComponent();
      expect(findStatusBadge().props('icon')).toBe('');
    });

    it('renders icon when items count is passed', () => {
      createComponent({ itemsCount });
      expect(findStatusBadge().props('icon')).toBe('check-circle');
    });

    it('renders icon when isCompleted is true', () => {
      createComponent({ isCompleted: true });
      expect(findStatusBadge().props('icon')).toBe('check-circle');
    });
  });

  describe('collapse', () => {
    it('renders collapse hidden by default', () => {
      createComponent();
      expect(findCollapse().props('visible')).toBe(false);
    });

    it('renders collapse expanded if initiallyExpanded is provided', () => {
      createComponent({ initiallyExpanded: true });
      expect(findCollapse().props('visible')).toBe(true);
    });

    it('renders expand button with icon', () => {
      createComponent();
      expect(findCollapseButton().exists()).toBe(true);
      expect(findCollapseButton().props('icon')).toBe('chevron-lg-right');
      expect(findCollapseButton().attributes('aria-label')).toBe('Expand');
    });

    it('expands collapse on clicking button', async () => {
      createComponent();
      await findCollapseButton().trigger('click');
      expect(findCollapse().props('visible')).toBe(true);
      expect(findCollapseButton().attributes('aria-label')).toBe('Collapse');
    });

    it('emits toggle event when component is created and when expanded state changes', async () => {
      createComponent();
      expect(wrapper.emitted('toggle')).toHaveLength(1);
      expect(wrapper.emitted('toggle')[0]).toEqual([false]);
      await findCollapseButton().trigger('click');
      expect(wrapper.emitted('toggle')).toHaveLength(2);
      expect(wrapper.emitted('toggle')[1]).toEqual([true]);

      await findCollapseButton().trigger('click');
      expect(wrapper.emitted('toggle')).toHaveLength(3);
      expect(wrapper.emitted('toggle')[2]).toEqual([false]);
    });
  });
});
