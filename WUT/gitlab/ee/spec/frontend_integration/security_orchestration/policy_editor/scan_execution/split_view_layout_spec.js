import { mountExtended } from 'helpers/vue_test_utils_helper';
import * as urlUtils from '~/lib/utils/url_utility';
import * as utils from 'ee/security_orchestration/components/policy_editor/scan_execution/lib/from_yaml';
import App from 'ee/security_orchestration/components/policy_editor/app.vue';
import { DEFAULT_ASSIGNED_POLICY_PROJECT } from 'ee/security_orchestration/constants';
import { POLICY_TYPE_COMPONENT_OPTIONS } from 'ee/security_orchestration/components/constants';
import { REPORT_TYPE_DAST } from '~/vue_shared/security_reports/constants';
import EditorLayout from 'ee/security_orchestration/components/policy_editor/editor_layout.vue';
import { DEFAULT_PROVIDE } from '../mocks/mocks';
import { mockDastActionScanExecutionManifest } from './mocks';

describe('Split View', () => {
  let wrapper;

  const createWrapper = ({ propsData = {}, provide = {}, glFeatures = {} } = {}) => {
    wrapper = mountExtended(App, {
      propsData: {
        assignedPolicyProject: DEFAULT_ASSIGNED_POLICY_PROJECT,
        ...propsData,
      },
      provide: {
        ...DEFAULT_PROVIDE,
        glFeatures,
        ...provide,
      },
    });
  };

  const findScanTypeSelector = () => wrapper.findByTestId('scan-type-selector');
  const findPolicyEditorLayout = () => wrapper.findComponent(EditorLayout);

  beforeEach(() => {
    jest
      .spyOn(urlUtils, 'getParameterByName')
      .mockReturnValue(POLICY_TYPE_COMPONENT_OPTIONS.scanExecution.urlParameter);
  });

  describe('rendering', () => {
    let createPolicyObjectMock;
    beforeEach(() => {
      createWrapper({
        provide: {
          glFeatures: { securityPoliciesSplitView: true },
          namespaceType: 'group',
        },
      });

      createPolicyObjectMock = jest
        .spyOn(utils, 'createPolicyObject')
        .mockImplementation(() => ({ policy: {}, parsingError: {} }));
    });

    it('updates policy only once when update via rule mode', async () => {
      await findScanTypeSelector().vm.$emit('select', REPORT_TYPE_DAST);
      expect(createPolicyObjectMock).toHaveBeenCalledTimes(0);
    });

    it('updated policy when yaml is updated', async () => {
      await findPolicyEditorLayout().vm.$emit('update-yaml', mockDastActionScanExecutionManifest);

      expect(createPolicyObjectMock).toHaveBeenCalledTimes(2);
    });
  });
});
