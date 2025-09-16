import DoraChartHeader from 'ee/analytics/dora/components/dora_chart_header.vue';
import { chartDescriptionText } from 'ee/analytics/dora/components/static_data/lead_time';
import { environmentTierDocumentationHref } from 'ee/analytics/dora/components/static_data/shared';
import { mountExtended } from 'helpers/vue_test_utils_helper';

describe('dora_chart_header.vue', () => {
  const mockHeaderText = 'Header text';
  const mockDocLink = 'https://example.com/docs';

  let wrapper;

  const createComponent = () => {
    wrapper = mountExtended(DoraChartHeader, {
      propsData: {
        headerText: mockHeaderText,
        chartDescriptionText,
        chartDocumentationHref: mockDocLink,
      },
    });
  };

  beforeEach(() => {
    createComponent();
  });

  it('renders the header text', () => {
    const actualText = wrapper.find('h2').text();

    expect(actualText).toBe(mockHeaderText);
  });

  it('renders a link to the documentation about deployment tier', () => {
    const link = wrapper.findByRole('link', { name: 'deployment_tier' });

    expect(link.attributes('href')).toBe(environmentTierDocumentationHref);
  });

  it('renders a "Learn more." documentation link', () => {
    const link = wrapper.findByRole('link', { name: 'Learn more.' });

    expect(link.attributes('href')).toBe(mockDocLink);
  });

  it('renders the chart description/help text', () => {
    const helpText = wrapper.findByTestId('help-text');

    expect(helpText.text()).toMatchInterpolatedText(
      'The chart displays the median time between a merge request being merged and deployed to production environment(s) that are based on the deployment_tier value. Learn more.',
    );
  });
});
