import { GlIcon, GlButton } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import SectionHeader from 'ee/pages/projects/get_started/components/section_header.vue';
import {
  ICON_TYPE_EMPTY,
  ICON_TYPE_PARTIAL,
  ICON_TYPE_COMPLETED,
} from 'ee/pages/projects/get_started/constants';

describe('SectionHeader', () => {
  let wrapper;

  const defaultSection = {
    title: 'Test Section',
    actions: [{ completed: true }, { completed: false }],
    trialActions: [{ completed: true }, { completed: false }],
  };

  const createSection = (overrides = {}) => ({
    ...defaultSection,
    ...overrides,
  });

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(SectionHeader, {
      propsData: {
        section: createSection(),
        isExpanded: false,
        sectionIndex: 0,
        ...props,
      },
    });
  };

  const findCompletionIcon = () => wrapper.findComponent(GlIcon);
  const findTitle = () => wrapper.findByTestId('section-title');
  const findCompletionText = () => wrapper.findByTestId('completion-text');
  const findExpandButton = () => wrapper.findComponent(GlButton);

  describe('rendering', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders the section title', () => {
      expect(findTitle().text()).toBe('Test Section');
    });

    it('renders the completion text', () => {
      expect(findCompletionText().text()).toBe('2/4 completed');
    });

    it('renders the expand button with correct icon and data-testid', () => {
      expect(findExpandButton().props('icon')).toBe('chevron-down');
      expect(findExpandButton().attributes('data-testid')).toBe('section-header-0');
    });
  });

  describe('completion status', () => {
    it('shows empty icon when no actions are completed', () => {
      createComponent({
        section: createSection({
          actions: [{ completed: false }, { completed: false }],
          trialActions: [{ completed: false }, { completed: false }],
        }),
      });

      expect(findCompletionIcon().props('name')).toBe(ICON_TYPE_EMPTY);
      expect(findTitle().classes('gl-line-through')).toBe(false);
    });

    it('shows partial icon when some actions are completed', () => {
      createComponent();

      expect(findCompletionIcon().props('name')).toBe(ICON_TYPE_PARTIAL);
      expect(findTitle().classes('gl-line-through')).toBe(false);
    });

    it('shows complete icon and line-through text when all actions are completed', () => {
      createComponent({
        section: createSection({
          actions: [{ completed: true }, { completed: true }],
          trialActions: [{ completed: true }, { completed: true }],
        }),
      });

      expect(findCompletionIcon().props('name')).toBe(ICON_TYPE_COMPLETED);
      expect(findTitle().classes('gl-line-through')).toBe(true);
    });

    it('shows empty icon when there are no actions', () => {
      createComponent({
        section: createSection({
          actions: [],
          trialActions: [],
        }),
      });

      expect(findCompletionIcon().props('name')).toBe(ICON_TYPE_EMPTY);
    });
  });

  describe('expand/collapse behavior', () => {
    it('shows correct button label and icon when collapsed', () => {
      createComponent({ isExpanded: false });

      expect(findExpandButton().attributes('aria-label')).toBe('Expand');
      expect(findExpandButton().props('icon')).toBe('chevron-down');
    });

    it('shows correct button label and icon when expanded', () => {
      createComponent({ isExpanded: true });

      expect(findExpandButton().attributes('aria-label')).toBe('Collapse');
      expect(findExpandButton().props('icon')).toBe('chevron-up');
    });

    it('emits toggle-expand event when expand button is clicked', async () => {
      createComponent();
      await findExpandButton().vm.$emit('click');

      expect(wrapper.emitted('toggle-expand')).toHaveLength(1);
      expect(wrapper.emitted('toggle-expand')[0]).toEqual([]);
    });
  });

  describe('completion text calculation', () => {
    it('handles section with only regular actions', () => {
      createComponent({
        section: createSection({
          actions: [{ completed: true }, { completed: false }],
          trialActions: [],
        }),
      });

      expect(findCompletionText().text()).toBe('1/2 completed');
    });

    it('handles section with only trial actions', () => {
      createComponent({
        section: createSection({
          actions: [],
          trialActions: [{ completed: true }, { completed: false }],
        }),
      });

      expect(findCompletionText().text()).toBe('1/2 completed');
    });

    it('handles section with undefined actions and trialActions', () => {
      createComponent({
        section: { title: 'Test Section' },
      });

      expect(findCompletionText().text()).toBe('0/0 completed');
    });
  });
});
