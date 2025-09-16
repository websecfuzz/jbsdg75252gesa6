import * as getters from 'ee/geo_replicable/store/getters';
import createState from 'ee/geo_replicable/store/state';
import { FILTER_OPTIONS } from 'ee/geo_replicable/constants';

describe('GeoReplicable Store Getters', () => {
  let state;

  beforeEach(() => {
    state = createState({ graphqlFieldName: null });
  });

  describe.each`
    statusFilter               | searchFilter | hasFilters
    ${FILTER_OPTIONS[0].value} | ${''}        | ${false}
    ${FILTER_OPTIONS[0].value} | ${'test'}    | ${true}
    ${FILTER_OPTIONS[1].value} | ${''}        | ${true}
    ${FILTER_OPTIONS[1].value} | ${'test'}    | ${true}
  `('hasFilters', ({ statusFilter, searchFilter, hasFilters }) => {
    beforeEach(() => {
      state.statusFilter = statusFilter;
      state.searchFilter = searchFilter;
    });

    it(`when statusFilter: ${statusFilter} and searchFilter: "${searchFilter}" hasFilters returns ${hasFilters}`, () => {
      expect(getters.hasFilters(state)).toBe(hasFilters);
    });
  });
});
