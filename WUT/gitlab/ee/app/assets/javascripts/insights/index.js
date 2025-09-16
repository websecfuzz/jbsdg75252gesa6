import Vue from 'vue';
import Insights from './components/insights.vue';
import createRouter from './insights_router';
import store from './stores';

export default () => {
  const el = document.querySelector('#js-insights-pane');
  const { endpoint, queryEndpoint, notice, namespaceType, fullPath } = el.dataset;
  const router = createRouter(endpoint);

  if (!el) return null;

  return new Vue({
    el,
    store,
    router,
    components: {
      Insights,
    },
    provide: {
      fullPath,
      isProject: namespaceType === 'project',
    },
    render(createElement) {
      return createElement('insights', {
        props: {
          endpoint,
          queryEndpoint,
          notice,
        },
      });
    },
  });
};
