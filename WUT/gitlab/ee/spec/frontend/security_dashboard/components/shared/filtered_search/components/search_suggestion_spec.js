import { GlFilteredSearchSuggestion, GlTruncate, GlIcon } from '@gitlab/ui';
import SearchSuggestion from 'ee/security_dashboard/components/shared/filtered_search/components/search_suggestion.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

describe('Search Suggestion', () => {
  let wrapper;

  const createWrapper = ({ text, name, value, selected, truncate }) => {
    wrapper = shallowMountExtended(SearchSuggestion, {
      propsData: {
        text,
        name,
        value,
        selected,
        truncate,
      },
    });
  };

  const findGlSearchSuggestion = () => wrapper.findComponent(GlFilteredSearchSuggestion);

  it.each`
    selected
    ${true}
    ${false}
  `('renders search suggestions as expected when selected is $selected', ({ selected }) => {
    createWrapper({
      text: 'My text',
      value: 'my_value',
      selected,
    });

    expect(wrapper.findComponent(SearchSuggestion).exists()).toBe(true);
    expect(wrapper.findByText('My text').exists()).toBe(true);
    expect(findGlSearchSuggestion().props('value')).toBe('my_value');
    expect(wrapper.findComponent(GlIcon).classes('gl-invisible')).toBe(!selected);
  });

  it.each`
    truncate
    ${true}
    ${false}
  `('truncates the text when `truncate` property is $truncate', ({ truncate }) => {
    createWrapper({ text: 'My text', value: 'My value', selected: false, truncate });
    expect(wrapper.findComponent(GlTruncate).exists()).toBe(truncate);
  });

  it('truncates the text when `truncate` property is $truncate', () => {
    createWrapper({ text: 'My text', value: 'My value', selected: false, truncate: true });
    expect(wrapper.findComponent(GlTruncate).props('text')).toBe('My text');
  });
});
