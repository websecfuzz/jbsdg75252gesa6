import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import BranchRule from '~/projects/settings/repository/branch_rules/components/branch_rule.vue';
import { branchRuleProvideMock, branchRulePropsMock } from '../mock_data';

describe('Branch rule', () => {
  let wrapper;

  const createComponent = ({ props = {}, provide = {} } = {}) => {
    wrapper = shallowMountExtended(BranchRule, {
      provide: { ...branchRuleProvideMock, ...provide },
      propsData: { ...branchRulePropsMock, ...props },
    });
  };

  const findProtectionDetailsListItems = () => wrapper.findAllByRole('listitem');
  const findCodeOwners = () => wrapper.findByText('Requires CODEOWNERS approval');
  const findStatusChecks = () => wrapper.findByText('2 status checks');
  const findApprovalRules = () => wrapper.findByText('1 approval rule');

  beforeEach(() => createComponent());

  it.each`
    showCodeOwners | showStatusChecks | showApprovers
    ${true}        | ${true}          | ${true}
    ${false}       | ${false}         | ${false}
  `(
    'conditionally renders code owners, status checks, and approval rules',
    ({ showCodeOwners, showStatusChecks, showApprovers }) => {
      createComponent({ provide: { showCodeOwners, showStatusChecks, showApprovers } });

      expect(findCodeOwners().exists()).toBe(showCodeOwners);
      expect(findStatusChecks().exists()).toBe(showStatusChecks);
      expect(findApprovalRules().exists()).toBe(showApprovers);
    },
  );

  it('renders the protection details list items', () => {
    expect(findProtectionDetailsListItems()).toHaveLength(wrapper.vm.approvalDetails.length);
    expect(findProtectionDetailsListItems().at(0).text()).toBe('Allowed to force push');
    expect(findProtectionDetailsListItems().at(1).text()).toBe(wrapper.vm.pushAccessLevelsText);
  });

  it('renders branches count for wildcards', () => {
    createComponent({ props: { name: 'test-*' } });
    expect(findProtectionDetailsListItems().at(0).text()).toBe('1 matching branch');
  });
});
