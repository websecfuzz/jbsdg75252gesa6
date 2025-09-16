import { toYaml } from 'ee/security_orchestration/components/policy_editor/scan_execution/lib';
import {
  customYaml,
  customYamlObject,
} from 'ee_jest/security_orchestration/mocks/mock_scan_execution_policy_data';

describe('toYaml', () => {
  it('returns policy object as yaml', () => {
    expect(toYaml(customYamlObject)).toBe(customYaml);
  });
});
