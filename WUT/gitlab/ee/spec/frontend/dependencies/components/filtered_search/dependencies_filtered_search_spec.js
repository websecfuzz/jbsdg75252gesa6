import { shallowMount } from '@vue/test-utils';
import { GlFilteredSearch } from '@gitlab/ui';
import DependenciesFilteredSearch from 'ee/dependencies/components/filtered_search/dependencies_filtered_search.vue';
import ComponentToken from 'ee/dependencies/components/filtered_search/tokens/component_token.vue';
import createStore from 'ee/dependencies/store';
import { markRaw } from '~/lib/utils/vue3compat/mark_raw';

describe('DependenciesFilteredSearch', () => {
  let wrapper;
  let store;

  const defaultToken = {
    title: 'Component',
    type: 'component_names',
    multiSelect: true,
    token: markRaw(ComponentToken),
  };

  const defaultPropsData = {
    filteredSearchId: 'some-filtered-search-id',
    tokens: [defaultToken],
  };

  const createVuexStore = () => {
    store = createStore();
    jest.spyOn(store, 'dispatch').mockImplementation();
  };

  const createComponent = ({
    props = {},
    slot = '',
    glFeatures = { projectDependenciesGraphql: true },
  } = {}) => {
    wrapper = shallowMount(DependenciesFilteredSearch, {
      store,
      propsData: {
        ...defaultPropsData,
        ...props,
      },
      provide: {
        glFeatures,
      },
      scopedSlots: { default: slot },
    });
  };

  const findFilteredSearch = () => wrapper.findComponent(GlFilteredSearch);

  beforeEach(createVuexStore);

  describe('GlFilteredSearch', () => {
    beforeEach(createComponent);

    it('sets the basic props correctly', () => {
      expect(findFilteredSearch().props()).toMatchObject({
        termsAsTokens: true,
      });
    });

    it('sets the id attribute', () => {
      const { filteredSearchId } = defaultPropsData;
      expect(findFilteredSearch().attributes('id')).toBe(filteredSearchId);
    });

    it('displays the correct placeholder', () => {
      expect(findFilteredSearch().props('placeholder')).toBe('Search or filter dependencies…');
    });

    it('passes the token configuration', () => {
      expect(findFilteredSearch().props('availableTokens')).toMatchObject(
        expect.arrayContaining([
          expect.objectContaining({
            ...defaultToken,
          }),
        ]),
      );
    });

    describe('submit', () => {
      it('dispatches the "fetchDependenciesViaGraphQL" Vuex action', () => {
        createComponent();
        expect(store.dispatch).not.toHaveBeenCalled();

        const filterPayload = [{ type: 'license', value: { data: ['MIT'] } }];
        findFilteredSearch().vm.$emit('submit', filterPayload);

        expect(store.dispatch).toHaveBeenCalledWith('fetchDependenciesViaGraphQL');
      });

      it('dispatches the "fetchDependencies" Vuex action when feature flag is disabled', () => {
        createComponent({ glFeatures: { projectDependenciesGraphql: false } });
        expect(store.dispatch).not.toHaveBeenCalled();

        const filterPayload = [{ type: 'license', value: { data: ['MIT'] } }];
        findFilteredSearch().vm.$emit('submit', filterPayload);

        expect(store.dispatch).toHaveBeenCalledWith('fetchDependencies', {
          page: 1,
        });
      });
    });
  });
});
