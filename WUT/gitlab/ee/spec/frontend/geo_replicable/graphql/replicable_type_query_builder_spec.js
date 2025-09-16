import { print } from 'graphql/language/printer';
import buildReplicableTypeQuery from 'ee/geo_replicable/graphql/replicable_type_query_builder';
import { MOCK_GRAPHQL_REGISTRY } from '../mock_data';

describe('buildReplicableTypeQuery', () => {
  describe('query fields', () => {
    it.each([true, false])('shows correct fields when verification=%s', (verificationEnabled) => {
      const query = buildReplicableTypeQuery(MOCK_GRAPHQL_REGISTRY, verificationEnabled);
      expect(print(query)).toMatchSnapshot();
    });
  });
});
