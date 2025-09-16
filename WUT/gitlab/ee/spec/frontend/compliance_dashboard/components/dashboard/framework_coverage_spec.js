import { shallowMount } from '@vue/test-utils';
import { GlEmptyState } from '@gitlab/ui';
import { GlChart } from '@gitlab/ui/dist/charts';
import { GL_LIGHT } from '~/constants';
import FrameworkCoverage from 'ee/compliance_dashboard/components/dashboard/framework_coverage.vue';
import { ROUTE_PROJECTS } from 'ee/compliance_dashboard/constants';

describe('Framework coverage panel', () => {
  let wrapper;
  const pushMock = jest.fn();

  function createComponent(details = []) {
    wrapper = shallowMount(FrameworkCoverage, {
      propsData: {
        summary: {
          totalProjects: 0,
          coveredCount: 0,
          details,
        },
        colorScheme: GL_LIGHT,
      },
      mocks: {
        $router: {
          push: pushMock,
        },
      },
    });
  }

  it('renders empty state when no frameworks are available', () => {
    createComponent();
    expect(wrapper.findComponent(GlEmptyState).exists()).toBe(true);
  });

  it('renders chart when frameworks are available', () => {
    createComponent([{ id: 1, coveredCount: 10, framework: {} }]);
    expect(wrapper.findComponent(GlChart).exists()).toBe(true);
  });

  it('takes to projects tab when chart is clicked', () => {
    createComponent([{ id: 1, coveredCount: 10, framework: {} }]);

    wrapper.findComponent(GlChart).vm.$emit('chartItemClicked');
    expect(pushMock).toHaveBeenCalledWith({ name: ROUTE_PROJECTS });
  });
});
