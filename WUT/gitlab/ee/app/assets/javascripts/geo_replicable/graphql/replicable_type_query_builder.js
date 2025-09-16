import { gql } from '@apollo/client/core';
import PageInfo from '~/graphql_shared/fragments/page_info.fragment.graphql';

// Query.geoNode to be renamed to Query.geoSite => https://gitlab.com/gitlab-org/gitlab/-/issues/396739
export default (graphQlFieldName, verificationEnabled) => {
  return gql`
    query($first: Int, $last: Int, $before: String!, $after: String!, $replicationState: ReplicationStateEnum) {
      geoNode {
        ${graphQlFieldName}(first: $first, last: $last, before: $before, after: $after, replicationState: $replicationState) {
          pageInfo {
            ...PageInfo
          }
          nodes {
            id
            state
            retryCount
            lastSyncFailure
            retryAt
            lastSyncedAt
            modelRecordId
            verifiedAt @include (if: ${verificationEnabled})
            verificationState @include (if: ${verificationEnabled})
            verificationFailure @include (if: ${verificationEnabled})
            createdAt
          }
        }
      }
    }
    ${PageInfo}
  `;
};
