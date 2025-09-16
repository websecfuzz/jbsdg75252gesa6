import { shallowMount } from '@vue/test-utils';
import MergeRequestAnalyticsApp from 'ee/analytics/merge_request_analytics/components/app.vue';
import FilterBar from 'ee/analytics/merge_request_analytics/components/filter_bar.vue';
import ThroughputChart from 'ee/analytics/merge_request_analytics/components/throughput_chart.vue';
import ThroughputTableProvider from 'ee/analytics/merge_request_analytics/components/throughput_table_provider.vue';
import DateRange from '~/analytics/shared/components/daterange.vue';
import UrlSync from '~/vue_shared/components/url_sync.vue';
import PageHeading from '~/vue_shared/components/page_heading.vue';

describe('MergeRequestAnalyticsApp', () => {
  let wrapper;

  function createComponent() {
    wrapper = shallowMount(MergeRequestAnalyticsApp, {
      propsData: {
        startDate: new Date('2020-05-01'),
        endDate: new Date('2020-10-01'),
      },
    });
  }

  beforeEach(() => {
    createComponent();
  });

  it('displays the page title', () => {
    const pageTitle = wrapper.findComponent(PageHeading).props('heading');

    expect(pageTitle).toBe('Merge request analytics');
  });

  it('displays the filter bar component', () => {
    expect(wrapper.findComponent(FilterBar).exists()).toBe(true);
  });

  it('displays the date range component', () => {
    expect(wrapper.findComponent(DateRange).exists()).toBe(true);
  });

  it('displays the throughput chart component', () => {
    expect(wrapper.findComponent(ThroughputChart).exists()).toBe(true);
  });

  it('displays the throughput table component', () => {
    expect(wrapper.findComponent(ThroughputTableProvider).exists()).toBe(true);
  });

  describe('url sync', () => {
    it('includes the url sync component', () => {
      expect(wrapper.findComponent(UrlSync).exists()).toBe(true);
    });

    it('has the start and end date params', () => {
      const urlSync = wrapper.findComponent(UrlSync);

      expect(urlSync.props('query')).toMatchObject({
        start_date: '2020-05-01',
        end_date: '2020-10-01',
      });
    });
  });
});
