import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import ModelVersionPerformance from '~/ml/model_registry/components/model_version_performance.vue';
import CandidateDetail from '~/ml/model_registry/components/candidate_detail.vue';
import createMockApollo from 'helpers/mock_apollo_helper';
import { convertCandidateFromGraphql } from '~/ml/model_registry/utils';
import getPackageFiles from '~/packages_and_registries/package_registry/graphql/queries/get_package_files.query.graphql';
import { packageFilesQuery } from 'jest/packages_and_registries/package_registry/mock_data';
import { modelVersionWithCandidate } from '../graphql_mock_data';

Vue.use(VueApollo);

let wrapper;
const createWrapper = (modelVersion = modelVersionWithCandidate, props = {}, provide = {}) => {
  const requestHandlers = [
    [getPackageFiles, jest.fn().mockResolvedValue(packageFilesQuery({ files: [] }))],
  ];

  const apolloProvider = createMockApollo(requestHandlers);
  wrapper = shallowMountExtended(ModelVersionPerformance, {
    apolloProvider,
    propsData: {
      allowArtifactImport: true,
      modelVersion,
      ...props,
    },
    provide: {
      projectPath: 'path/to/project',
      canWriteModelRegistry: true,
      importPath: 'path/to/import',
      maxAllowedFileSize: 99999,
      ...provide,
    },
  });
};

const findCandidateDetail = () => wrapper.findComponent(CandidateDetail);

describe('ml/model_registry/components/model_version_detail.vue', () => {
  describe('base behaviour', () => {
    beforeEach(() => createWrapper());

    it('shows the candidate', () => {
      expect(findCandidateDetail().props('candidate')).toMatchObject(
        convertCandidateFromGraphql(modelVersionWithCandidate.candidate),
      );
    });
  });
});
