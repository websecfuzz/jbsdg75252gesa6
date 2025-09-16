import * as urlUtils from '~/lib/utils/url_utility';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { POLICY_TYPE_COMPONENT_OPTIONS } from 'ee/security_orchestration/components/constants';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import App from 'ee/security_orchestration/components/policy_editor/app.vue';
import PolicyTypeSelector from 'ee/security_orchestration/components/policy_editor/policy_type_selector.vue';
import EditorWrapper from 'ee/security_orchestration/components/policy_editor/editor_wrapper.vue';

describe('App component', () => {
  let wrapper;

  const findPolicySelection = () => wrapper.findComponent(PolicyTypeSelector);
  const findPolicyEditor = () => wrapper.findComponent(EditorWrapper);
  const findTitle = () => wrapper.findByTestId('page-heading').text();

  const factory = ({ provide = {} } = {}) => {
    wrapper = shallowMountExtended(App, {
      provide: { assignedPolicyProject: {}, ...provide },
      stubs: { PageHeading },
    });
  };

  describe('rendering', () => {
    it('displays the policy selection when there is no query parameter', () => {
      factory();
      expect(findPolicySelection().exists()).toBe(true);
      expect(findPolicyEditor().exists()).toBe(false);
    });

    it('displays the policy editor when there is a type query parameter', () => {
      jest
        .spyOn(urlUtils, 'getParameterByName')
        .mockReturnValue(POLICY_TYPE_COMPONENT_OPTIONS.approval.urlParameter);
      factory({ provide: { existingPolicy: { id: 'policy-id', value: 'approval' } } });
      expect(findPolicySelection().exists()).toBe(false);
      expect(findPolicyEditor().exists()).toBe(true);
      expect(findPolicyEditor().props('selectedPolicy')).toEqual(
        POLICY_TYPE_COMPONENT_OPTIONS.legacyApproval,
      );
    });
  });

  describe('page title', () => {
    describe.each`
      value                        | titleSuffix                          | expectedPolicy
      ${'approval'}                | ${'merge request approval policy'}   | ${POLICY_TYPE_COMPONENT_OPTIONS.legacyApproval}
      ${'scanExecution'}           | ${'scan execution policy'}           | ${POLICY_TYPE_COMPONENT_OPTIONS.scanExecution}
      ${'pipelineExecution'}       | ${'pipeline execution policy'}       | ${POLICY_TYPE_COMPONENT_OPTIONS.pipelineExecution}
      ${'vulnerabilityManagement'} | ${'vulnerability management policy'} | ${POLICY_TYPE_COMPONENT_OPTIONS.vulnerabilityManagement}
    `('$titleSuffix', ({ titleSuffix, value, expectedPolicy }) => {
      beforeEach(() => {
        jest
          .spyOn(urlUtils, 'getParameterByName')
          .mockReturnValue(POLICY_TYPE_COMPONENT_OPTIONS[value].urlParameter);
      });

      it('displays for a new policy', () => {
        factory();
        expect(findTitle()).toBe(`New ${titleSuffix}`);
        expect(findPolicyEditor().props('selectedPolicy')).toEqual(expectedPolicy);
      });

      it('displays for an existing policy', () => {
        factory({ provide: { existingPolicy: { id: 'policy-id', value } } });
        expect(findTitle()).toBe(`Edit ${titleSuffix}`);
        expect(findPolicyEditor().props('selectedPolicy')).toEqual(expectedPolicy);
      });
    });

    describe('invalid url parameter', () => {
      beforeEach(() => {
        jest.spyOn(urlUtils, 'getParameterByName').mockReturnValue('invalid');
      });

      it('displays for a new policy', () => {
        factory();
        expect(findTitle()).toBe('New policy');
        expect(findPolicyEditor().exists()).toBe(false);
      });

      it('displays for an existing policy', () => {
        factory({ provide: { existingPolicy: { id: 'policy-id', value: 'scanResult' } } });
        expect(findTitle()).toBe('Edit policy');
        expect(findPolicyEditor().exists()).toBe(false);
      });
    });
  });
});
