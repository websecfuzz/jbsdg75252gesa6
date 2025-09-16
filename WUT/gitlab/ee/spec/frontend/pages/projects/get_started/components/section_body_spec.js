import { GlCollapse } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import SectionBody from 'ee/pages/projects/get_started/components/section_body.vue';
import ActionItem from 'ee/pages/projects/get_started/components/action_item.vue';

describe('SectionBody', () => {
  let wrapper;

  const defaultActions = [{ title: 'Action 1' }, { title: 'Action 2' }];
  const defaultTrialActions = [{ title: 'Trial Action 1' }, { title: 'Trial Action 2' }];

  const createSection = (overrides = {}) => ({
    title: 'Test Section',
    description: 'Test Description',
    actions: defaultActions,
    trialActions: defaultTrialActions,
    ...overrides,
  });

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(SectionBody, {
      propsData: {
        section: createSection(),
        isExpanded: true,
        ...props,
      },
    });
  };

  const findCollapse = () => wrapper.findComponent(GlCollapse);
  const findDescription = () => wrapper.findByTestId('description-text');
  const findDescriptionIcon = () => wrapper.findByTestId('description-icon');
  const findActionItems = () => wrapper.findAllComponents(ActionItem);
  const findRegularActionItems = () => wrapper.findAllByTestId('action-item');
  const findTrialActionItems = () => wrapper.findAllByTestId('trial-action-item');
  const findDivider = () => wrapper.findByTestId('divider');
  const findTrialHeader = () => wrapper.findByTestId('trial-description-text');
  const findTrialIcon = () => wrapper.findByTestId('trial-icon');

  describe('rendering', () => {
    describe('description', () => {
      it('renders the component with description and respects isExpanded prop', () => {
        createComponent();

        expect(findDescription().text()).toBe('Test Description');
        expect(findCollapse().props('visible')).toBe(true);
      });

      it('collapses content when isExpanded is false', () => {
        createComponent({ isExpanded: false });

        expect(findCollapse().props('visible')).toBe(false);
      });

      it('renders description icon when provided', () => {
        createComponent({ section: createSection({ descriptionIcon: 'license' }) });

        expect(findDescriptionIcon().exists()).toBe(true);
        expect(findDescriptionIcon().props('name')).toBe('license');
      });

      it('does not render description icon when not provided', () => {
        createComponent();

        expect(findDescriptionIcon().exists()).toBe(false);
      });
    });

    describe('action items', () => {
      it('renders regular action items correctly', () => {
        createComponent();

        const regularItems = findRegularActionItems();
        expect(regularItems).toHaveLength(2);
        expect(regularItems.at(0).props('action')).toEqual(defaultActions[0]);
        expect(regularItems.at(1).props('action')).toEqual(defaultActions[1]);
      });

      it('renders trial action items correctly', () => {
        createComponent();

        const trialItems = findTrialActionItems();
        expect(trialItems).toHaveLength(2);
        expect(trialItems.at(0).props('action')).toEqual(defaultTrialActions[0]);
        expect(trialItems.at(1).props('action')).toEqual(defaultTrialActions[1]);
      });
    });

    describe('trial section', () => {
      it('renders trial section divider and header when trial actions exist', () => {
        createComponent();

        expect(findDivider().exists()).toBe(true);
        expect(findTrialHeader().text()).toBe('Included in trial');
        expect(findTrialIcon().props('name')).toBe('license');
      });

      it('does not render trial section elements when no trial actions', () => {
        createComponent({ section: createSection({ trialActions: [] }) });

        expect(findDivider().exists()).toBe(false);
        expect(findTrialIcon().exists()).toBe(false);
      });
    });
  });

  describe('edge cases', () => {
    it('handles section with no regular actions', () => {
      createComponent({ section: createSection({ actions: [] }) });

      expect(findRegularActionItems()).toHaveLength(0);
      expect(findTrialActionItems()).toHaveLength(2);
    });

    it('handles section with no trial actions', () => {
      createComponent({ section: createSection({ trialActions: [] }) });

      expect(findRegularActionItems()).toHaveLength(2);
      expect(findTrialActionItems()).toHaveLength(0);
    });

    it('handles section with no actions at all', () => {
      createComponent({ section: createSection({ actions: [], trialActions: [] }) });

      expect(findActionItems()).toHaveLength(0);
    });

    it('handles section with undefined actions properties', () => {
      createComponent({ section: { description: 'Test Description' } });

      expect(findActionItems()).toHaveLength(0);
    });
  });
});
