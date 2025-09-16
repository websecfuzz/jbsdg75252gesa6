import { extractGraphqlAiData } from 'ee/analytics/dashboards/ai_impact/api';

describe('AI impact dashboard api', () => {
  describe('extractGraphqlAiData', () => {
    const buildResponse = (
      [codeSuggestionsContributorsCount, codeContributorsCount],
      [codeSuggestionsAcceptedCount, codeSuggestionsShownCount],
      duoChatContributorsCount,
      rootCauseAnalysisUsersCount,
      duoAssignedUsersCount,
      // eslint-disable-next-line max-params
    ) => ({
      codeSuggestionsContributorsCount,
      codeContributorsCount,
      codeSuggestionsAcceptedCount,
      codeSuggestionsShownCount,
      duoChatContributorsCount,
      duoAssignedUsersCount,
      rootCauseAnalysisUsersCount,
    });

    it.each([
      buildResponse([undefined, 5], [undefined, 4], undefined, undefined, 3),
      buildResponse([2, undefined], [3, undefined], 4, 10, undefined),
      buildResponse([5, 10], [3, 4], 7, 5, 8),
      buildResponse([0, 10], [0, 20], 0, 0, 50),
    ])('extracts data correctly when response is %s', (response) => {
      expect(extractGraphqlAiData(response)).toMatchSnapshot();
    });
  });
});
