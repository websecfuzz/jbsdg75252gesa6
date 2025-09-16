import { GlFilteredSearchToken } from '@gitlab/ui';
import Vue, { nextTick } from 'vue';
import VueRouter from 'vue-router';
import VueApollo from 'vue-apollo';
import IdentifierToken from 'ee/security_dashboard/components/shared/filtered_search/tokens/identifier_token.vue';
import QuerystringSync from 'ee/security_dashboard/components/shared/filters/querystring_sync.vue';
import eventHub from 'ee/security_dashboard/components/shared/filtered_search/event_hub';
import projectIdentifierSearch from 'ee/security_dashboard/graphql/queries/project_identifiers.query.graphql';
import groupIdentifierSearch from 'ee/security_dashboard/graphql/queries/group_identifiers.query.graphql';
import SearchSuggestion from 'ee/security_dashboard/components/shared/filtered_search/components/search_suggestion.vue';
import { capitalizeFirstCharacter } from '~/lib/utils/text_utility';
import { OPERATORS_IS } from '~/vue_shared/components/filtered_search_bar/constants';
import { createAlert } from '~/alert';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import { stubComponent } from 'helpers/stub_component';

Vue.use(VueApollo);
Vue.use(VueRouter);

jest.mock('~/alert');

describe('Identifier Token component', () => {
  let wrapper;
  let router;
  let eventSpy;
  const projectFullPath = 'test/path';
  const mockConfig = {
    multiSelect: false,
    unique: true,
    operators: OPERATORS_IS,
  };

  const createMockApolloProvider = ({ handlers = {}, namespace, query } = {}) => {
    const capitalized = capitalizeFirstCharacter(namespace);

    const defaultHandlers = {
      identifierSearch: jest.fn().mockResolvedValue({
        data: {
          [namespace]: {
            id: `gid://gitlab/${capitalized}/19`,
            vulnerabilityIdentifierSearch: ['CVE-2018-3741'],
            __typename: capitalized,
          },
        },
      }),
    };

    const handlerMocks = { ...defaultHandlers, ...handlers };
    const requestHandlers = [[query, handlerMocks.identifierSearch]];

    return createMockApollo(requestHandlers);
  };

  const createWrapper = ({
    value = {},
    active = false,
    stubs,
    provide = {},
    handlers = {},
    namespace = 'project',
    query = projectIdentifierSearch,
    mountFn = shallowMountExtended,
  } = {}) => {
    router = new VueRouter({ mode: 'history' });

    wrapper = mountFn(IdentifierToken, {
      router,
      propsData: {
        config: mockConfig,
        value,
        active,
      },
      provide: {
        portalName: 'fake target',
        alignSuggestions: jest.fn(),
        termsAsTokens: () => true,
        projectFullPath,
        ...provide,
      },
      stubs: {
        SearchSuggestion,
        GlFilteredSearchToken: stubComponent(GlFilteredSearchToken, {
          template: `
              <div>
                  <div data-testid="slot-view">
                      <slot name="view"></slot>
                  </div>
                  <div data-testid="slot-suggestions">
                      <slot name="suggestions"></slot>
                  </div>
              </div>`,
        }),
        ...stubs,
      },
      apolloProvider: createMockApolloProvider({
        namespace,
        handlers,
        query,
      }),
    });
  };

  const findQuerystringSync = () => wrapper.findComponent(QuerystringSync);
  const findFilteredSearchToken = () => wrapper.findComponent(GlFilteredSearchToken);

  const searchTerm = async (data) => {
    findFilteredSearchToken().vm.$emit('input', { data });
    await nextTick();
    jest.advanceTimersByTime(300); // Debounce time
  };

  const selectOption = (identifier) => {
    findFilteredSearchToken().vm.$emit('select', identifier);
    findFilteredSearchToken().vm.$emit('complete');
  };

  afterEach(() => {
    eventHub.$off('filters-changed', eventSpy);
  });

  describe('default view', () => {
    beforeEach(() => {
      createWrapper({ active: true });
    });

    it('displays a dropdown when a term is searched', async () => {
      const CVE = 'CVE-2018-3741';

      eventSpy = jest.fn();
      eventHub.$on('filters-changed', eventSpy);

      await searchTerm('CVE-2018');
      await waitForPromises();

      expect(wrapper.findByTestId(`suggestion-${CVE}`).exists()).toBe(true);

      // The alert should not be called on succesful calls
      expect(createAlert).not.toHaveBeenCalled();

      await selectOption(CVE);

      expect(eventSpy).toHaveBeenCalledWith({
        identifierName: CVE,
      });

      expect(eventSpy).toHaveBeenCalledTimes(1);
    });

    // See discussion: https://gitlab.com/gitlab-org/gitlab/-/issues/452492#note_2243422709
    it('does not emit double quote encapsulated identifiers', async () => {
      const identifier = 'A1:2017 CVE-xyz';

      eventSpy = jest.fn();
      eventHub.$on('filters-changed', eventSpy);

      // The Filtered Search sends a quoted text when there are characters like `/`, `:`.
      // This makes sure we test sending raw values.
      await selectOption(`"${identifier}"`);

      expect(eventSpy).toHaveBeenCalledWith({
        identifierName: identifier,
      });

      expect(eventSpy).toHaveBeenCalledTimes(1);
    });

    it('shows an error message when query fails', async () => {
      createWrapper({
        active: true,
        handlers: { identifierSearch: jest.fn().mockRejectedValue() },
      });

      await searchTerm('CVE-2018');
      await waitForPromises();

      expect(createAlert).toHaveBeenCalledWith({
        message:
          'There was an error fetching the identifiers for this project. Please try again later.',
      });
    });

    it('clears data when user presses backspace', async () => {
      await searchTerm('cve-2022-123');

      wrapper.vm.resetSearchTerm = jest.fn();

      await searchTerm('');

      expect(wrapper.vm.resetSearchTerm).toHaveBeenCalledWith({ emit: false });

      // Also test that `null` value is working when `multiSelect=false`
      // This aligns with the behaviour when `multiSelect=true`
      wrapper.vm.resetSearchTerm = jest.fn();

      await searchTerm(null);

      expect(wrapper.vm.resetSearchTerm).toHaveBeenCalledWith({ emit: false });
    });

    it('clears data when user destroys the token', async () => {
      await searchTerm('cve-2022-123');

      eventSpy = jest.fn();
      eventHub.$on('filters-changed', eventSpy);

      findFilteredSearchToken().vm.$emit('destroy');

      expect(eventSpy).toHaveBeenCalledWith({
        identifierName: '',
      });
    });

    it('displays a placeholder before a term is searched', async () => {
      const phText = 'Enter at least 3 characters to view available identifiers.';
      expect(wrapper.text()).toBe(phText);
      await searchTerm('cve-');
      expect(wrapper.text()).not.toContain(phText);
    });

    it('displays a helper text when no results are found', async () => {
      createWrapper({
        active: true,
        handlers: { identifierSearch: jest.fn().mockResolvedValue({ data: { project: {} } }) },
      });

      const notFoundText = 'No identifiers found';
      expect(wrapper.text()).not.toContain(notFoundText);
      await searchTerm('cve');
      await waitForPromises();
      expect(wrapper.text()).toContain(notFoundText);
    });
  });

  describe('group level', () => {
    beforeEach(() => {
      createWrapper({
        provide: {
          projectFullPath: '',
          groupFullPath: 'my-group',
        },
        query: groupIdentifierSearch,
        namespace: 'group',
      });
    });

    it('handles fuzzy search', async () => {
      const CVE = 'CVE-2018-3741';

      eventSpy = jest.fn();
      eventHub.$on('filters-changed', eventSpy);

      await searchTerm('CVE-2018');
      await waitForPromises();

      expect(wrapper.findByTestId(`suggestion-${CVE}`).exists()).toBe(true);

      // The alert should not be called on succesful calls
      expect(createAlert).not.toHaveBeenCalled();

      await selectOption(CVE);

      expect(eventSpy).toHaveBeenCalledWith({
        identifierName: CVE,
      });

      expect(eventSpy).toHaveBeenCalledTimes(1);
    });
  });

  describe('QuerystringSync component', () => {
    beforeEach(() => {
      eventSpy = jest.fn();
      eventHub.$on('filters-changed', eventSpy);
      createWrapper();
    });

    it('has expected props', () => {
      expect(findQuerystringSync().props()).toMatchObject({
        querystringKey: 'identifier',
        value: [],
      });
    });

    it('does not emit an event on initial load', () => {
      expect(eventSpy).not.toHaveBeenCalled();
    });

    it('emits an event when initial value is not empty', () => {
      createWrapper({ value: { data: ['cve-test'] } });
      expect(eventSpy).toHaveBeenCalledWith({ identifierName: 'cve-test' });
    });
  });
});
