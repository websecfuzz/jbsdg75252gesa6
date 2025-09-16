import { nextTick } from 'vue';
import { shallowMount } from '@vue/test-utils';
import { GlEmptyState } from '@gitlab/ui';
import ProductAnalyticsUsageQuotaApp from 'ee/usage_quotas/product_analytics/components/product_analytics_usage_quota_app.vue';
import ProductAnalyticsGroupUsage from 'ee/usage_quotas/product_analytics/components/group_usage/product_analytics_group_usage.vue';
import ProductAnalyticsProjectsUsage from 'ee/usage_quotas/product_analytics/components/projects_usage/product_analytics_projects_usage.vue';

describe('ProductAnalyticsUsageQuotaApp', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;

  const findEmptyState = () => wrapper.findComponent(GlEmptyState);
  const findProductAnalyticsGroupUsage = () => wrapper.findComponent(ProductAnalyticsGroupUsage);
  const findProductAnalyticsProjectsUsage = () =>
    wrapper.findComponent(ProductAnalyticsProjectsUsage);

  const createComponent = ({ productAnalyticsEnabled }) => {
    wrapper = shallowMount(ProductAnalyticsUsageQuotaApp, {
      provide: {
        emptyStateIllustrationPath: '/empty-state.svg',
        productAnalyticsEnabled,
      },
    });
  };

  describe('when product analytics is disabled', () => {
    beforeEach(() => createComponent({ productAnalyticsEnabled: false }));

    it('renders an empty state', () => {
      expect(findEmptyState().props()).toMatchObject({
        description:
          "Track your product's performance, and optimize your product and development processes.",
        primaryButtonLink:
          '/help/development/internal_analytics/product_analytics#enable-product-analytics',
        primaryButtonText: 'Learn how to enable product analytics',
        svgPath: '/empty-state.svg',
        title: 'Get started with product analytics',
      });
    });
  });

  describe('when product analytics is enabled', () => {
    beforeEach(() => createComponent({ productAnalyticsEnabled: true }));

    it('renders the monthly group usage chart', () => {
      expect(findProductAnalyticsGroupUsage().exists()).toBe(true);
    });

    it('renders the projects usage breakdown', () => {
      expect(findProductAnalyticsProjectsUsage().exists()).toBe(true);
    });

    describe('when there are no onboarded projects within the group', () => {
      beforeEach(() => {
        findProductAnalyticsGroupUsage().vm.$emit('no-projects');
        return nextTick();
      });

      it('renders an empty state', () => {
        expect(findEmptyState().props()).toMatchObject({
          description:
            'This group has no projects with product analytics onboarded in the current period.',
          primaryButtonLink:
            '/help/development/internal_analytics/product_analytics#onboard-a-gitlab-project',
          primaryButtonText: 'Learn how to onboard projects',
          svgPath: '/empty-state.svg',
          title: 'No projects found',
        });
      });
    });
  });
});
