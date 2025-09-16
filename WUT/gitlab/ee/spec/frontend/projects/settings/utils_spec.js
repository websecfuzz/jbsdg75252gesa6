import { getAccessLevels, getAccessLevelInputFromEdges } from 'ee/projects/settings/utils';
import { accessLevelsMockResponse, accessLevelsMockResult } from './mock_data';

describe('EE Utils', () => {
  describe('getAccessLevels', () => {
    it('takes accessLevels response data and returns accessLevels object', () => {
      const mergeAccessLevels = getAccessLevels(accessLevelsMockResponse);
      expect(mergeAccessLevels).toEqual(accessLevelsMockResult);
    });
  });

  describe('getAccessLevelInputFromEdges', () => {
    it('returns an empty array when given an empty array', () => {
      const edges = [];
      const result = getAccessLevelInputFromEdges(edges);

      expect(result).toEqual([]);
    });

    it('returns an array with accessLevel when node has accessLevel', () => {
      const edges = [{ node: { accessLevel: 30 } }];
      const result = getAccessLevelInputFromEdges(edges);

      expect(result).toEqual([{ accessLevel: 30 }]);
    });

    it('returns an array with deployKeys when node has deployKeys', () => {
      const edges = [{ node: { deployKey: { id: 14 } } }];
      const result = getAccessLevelInputFromEdges(edges);

      expect(result).toEqual([{ deployKeyId: 14 }]);
    });

    it('returns an array with groupId when node has group.id', () => {
      const edges = [{ node: { group: { id: 1 } } }];
      const result = getAccessLevelInputFromEdges(edges);

      expect(result).toEqual([{ groupId: 1 }]);
    });

    it('returns an array with userId when node has user.id', () => {
      const edges = [{ node: { user: { id: 2 } } }];
      const result = getAccessLevelInputFromEdges(edges);

      expect(result).toEqual([{ userId: 2 }]);
    });

    it('returns an array with groupId, and userId when node has all properties', () => {
      const edges = [
        {
          node: {
            accessLevel: 30,
            group: { id: 1 },
            user: { id: 2 },
          },
        },
      ];
      const result = getAccessLevelInputFromEdges(edges);

      expect(result).toEqual([{ groupId: 1, userId: 2 }]);
    });

    it('returns an array with multiple objects when given multiple edges', () => {
      const edges = [
        { node: { accessLevel: 30, group: { id: 1 } } },
        { node: { user: { id: 2 } } },
        { node: { accessLevel: 40 } },
      ];
      const result = getAccessLevelInputFromEdges(edges);

      expect(result).toEqual([{ groupId: 1 }, { userId: 2 }, { accessLevel: 40 }]);
    });
  });
});
