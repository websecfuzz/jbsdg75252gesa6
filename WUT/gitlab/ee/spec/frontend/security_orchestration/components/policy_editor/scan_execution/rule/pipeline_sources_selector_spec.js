import { GlCollapsibleListbox } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import PipelineSourceSelector from 'ee/security_orchestration/components/policy_editor/scan_execution/rule/pipeline_source_selector.vue';
import {
  PIPELINE_SOURCE_LISTBOX_OPTIONS,
  TARGETS_BRANCHES_PIPELINE_SOURCE_LISTBOX_OPTIONS,
} from 'ee/security_orchestration/components/policy_editor/scan_execution/constants';

describe('PipelineSourceSelector', () => {
  let wrapper;

  const createComponent = ({ allSources = true, including = [] } = {}) => {
    wrapper = shallowMountExtended(PipelineSourceSelector, {
      propsData: {
        allSources,
        pipelineSources: { including },
      },
    });
  };

  const findListbox = () => wrapper.findComponent(GlCollapsibleListbox);

  describe('rendering', () => {
    it('renders the dropdown with all sources by default', () => {
      createComponent();

      const listbox = findListbox();
      expect(listbox.exists()).toBe(true);
      expect(listbox.props('multiple')).toBe(true);
      expect(listbox.props('items')).toEqual(PIPELINE_SOURCE_LISTBOX_OPTIONS);
      expect(listbox.props('selected')).toEqual([]);
    });

    it('renders the dropdown with limited sources based on `allSources` prop', () => {
      createComponent({ allSources: false });

      const listbox = findListbox();
      expect(listbox.exists()).toBe(true);
      expect(listbox.props('multiple')).toBe(true);
      expect(listbox.props('items')).toEqual(TARGETS_BRANCHES_PIPELINE_SOURCE_LISTBOX_OPTIONS);
      expect(listbox.props('selected')).toEqual([]);
    });

    it('renders selected sources in the dropdown', () => {
      const selectedSources = ['web', 'api'];
      createComponent({ including: selectedSources });

      expect(findListbox().props('selected')).toEqual(selectedSources);
    });

    it('displays placeholder text when no sources are selected', () => {
      createComponent();

      expect(findListbox().props('toggleText')).toBe('All pipeline sources');
    });

    it('displays source name when one source is selected', () => {
      const selectedSource = 'web';
      createComponent({ including: [selectedSource] });

      // Find the text representation of the selected source
      const sourceText = PIPELINE_SOURCE_LISTBOX_OPTIONS.find(
        (option) => option.value === selectedSource,
      ).text;
      expect(findListbox().props('toggleText')).toBe(sourceText);
    });

    it('displays multiple source names when multiple sources are selected', () => {
      const selectedSources = ['web', 'api'];
      createComponent({ including: selectedSources });

      // The toggle text should contain both source names
      const toggleText = findListbox().props('toggleText');

      // Check that both source texts are included
      selectedSources.forEach((source) => {
        const sourceText = PIPELINE_SOURCE_LISTBOX_OPTIONS.find(
          (option) => option.value === source,
        ).text;
        expect(toggleText).toContain(sourceText);
      });
    });

    it('truncates display text when more than 2 sources are selected', () => {
      const selectedSources = ['api', 'push', 'web'];
      createComponent({ including: selectedSources });

      const toggleText = findListbox().props('toggleText');

      // Should show first two options and a count
      const apiText = PIPELINE_SOURCE_LISTBOX_OPTIONS.find((option) => option.value === 'api').text;
      const pushText = PIPELINE_SOURCE_LISTBOX_OPTIONS.find(
        (option) => option.value === 'push',
      ).text;

      expect(toggleText).toContain(apiText);
      expect(toggleText).toContain(pushText);
      expect(toggleText).toContain('1 more');
    });
  });

  describe('user interactions', () => {
    it('emits update event with selected sources when user selects a source', () => {
      createComponent();

      const selectedSources = ['web'];
      findListbox().vm.$emit('select', selectedSources);

      expect(wrapper.emitted('select')).toHaveLength(1);
      expect(wrapper.emitted('select')[0][0]).toEqual({
        pipeline_sources: { including: selectedSources },
      });
    });

    it('emits update event with multiple selected sources', () => {
      createComponent({ including: ['web'] });

      const selectedSources = ['web', 'api'];
      findListbox().vm.$emit('select', selectedSources);

      expect(wrapper.emitted('select')).toHaveLength(1);
      expect(wrapper.emitted('select')[0][0]).toEqual({
        pipeline_sources: { including: selectedSources },
      });
    });

    it('emits update event with empty array when all sources are deselected', () => {
      createComponent({ including: ['web', 'api'] });

      findListbox().vm.$emit('select', []);

      expect(wrapper.emitted('select')).toHaveLength(1);
      expect(wrapper.emitted('select')[0][0]).toEqual({
        pipeline_sources: { including: [] },
      });
    });
  });
});
