import { shallowMount } from '@vue/test-utils';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlCollapse, GlBadge, GlPopover, GlLink, GlSprintf } from '@gitlab/ui';
import HelpIcon from '~/vue_shared/components/help_icon/help_icon.vue';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import CodeOwners, {
  i18n,
  codeOwnersHelpPath,
} from 'ee_component/vue_shared/components/code_owners/code_owners.vue';
import codeOwnersInfoQuery from 'ee/graphql_shared/queries/code_owners_info.query.graphql';
import { toNounSeriesText } from '~/lib/utils/grammar';
import { extendedWrapper } from 'helpers/vue_test_utils_helper';
import { codeOwnersPath, codeOwnersMock, codeOwnersPropsMock } from '../mock_data';

let wrapper;
let mockResolver;

const createComponent = async ({ props = {}, codeOwnersDataMock = codeOwnersMock } = {}) => {
  Vue.use(VueApollo);

  const project = {
    id: '1234',
    repository: {
      codeOwnersPath,
      blobs: {
        nodes: [{ id: '345', codeOwners: codeOwnersDataMock }],
      },
    },
  };

  mockResolver = jest.fn().mockResolvedValue({ data: { project } });

  wrapper = extendedWrapper(
    shallowMount(CodeOwners, {
      apolloProvider: createMockApollo([[codeOwnersInfoQuery, mockResolver]]),
      propsData: {
        ...codeOwnersPropsMock,
        ...props,
      },
      stubs: {
        GlSprintf,
        HelpIcon,
      },
    }),
  );

  await waitForPromises();
};

describe('Code owners component', () => {
  const findCollapse = () => wrapper.findComponent(GlCollapse);
  const findCodeOwners = () => findCollapse().findAllComponents(GlLink);
  const findToggle = () => wrapper.findByTestId('collapse-toggle');
  const findBranchRulesLink = () => wrapper.findByTestId('branch-rules-link');
  const findLinkToFile = () => wrapper.findByTestId('codeowners-file-link');
  const findLinkToDocs = () => wrapper.findByTestId('codeowners-docs-link');
  const findNoCodeownersText = () => wrapper.findByTestId('no-codeowners-text');
  const findBadge = () => wrapper.findComponent(GlBadge);
  const findHelpPopoverTrigger = () => wrapper.findByTestId('help-popover-trigger');
  const findHelpPopover = () => wrapper.findComponent(GlPopover);
  const findHelpPopoverLink = () => findHelpPopover().findComponent(GlLink);
  const findCodeOwnersActions = () => wrapper.findByTestId('code-owners-actions');
  beforeEach(() => createComponent());

  describe('Default state', () => {
    it('renders a link to CODEOWNERS file', () => {
      expect(findLinkToFile().attributes('href')).toBe(codeOwnersPath);
    });

    it('renders a Badge with a Number of codeowners', () => {
      expect(findBadge().text()).toBe(`${codeOwnersMock.length}`);
    });

    it('renders a toggle button with correct text', () => {
      expect(findToggle().exists()).toBe(true);
      expect(findToggle().text()).toBe(i18n.showAll);
    });

    it('expands when you click on a toggle', async () => {
      await findToggle().vm.$emit('click');
      await nextTick();
      expect(findCollapse().props('visible')).toBe(true);
      expect(findToggle().text()).toBe(i18n.hideAll);
    });

    it('renders codeowners list', () => {
      expect(findCodeOwners()).toHaveLength(codeOwnersMock.length);
    });

    it('renders a popover trigger with question icon', () => {
      expect(findHelpPopoverTrigger().findComponent(HelpIcon).attributes('name')).toBe(
        'question-o',
      );
      expect(findHelpPopoverTrigger().attributes('aria-label')).toBe(i18n.helpText);
    });

    it('renders a popover', () => {
      expect(findHelpPopoverTrigger().attributes('id')).toBe(findHelpPopover().props('target'));
      expect(findHelpPopover().props()).toMatchObject({
        placement: 'top',
        triggers: 'hover focus',
      });
      expect(findHelpPopoverLink().exists()).toBe(true);
      expect(findHelpPopover().text()).toContain(i18n.helpText);
    });
  });

  describe('codeowner actions renders when there are codeowners or the user has access to branch rules', () => {
    it('when there are codeowners but the user does not have access to branch rules the codeowner actions section is rendered', async () => {
      await createComponent({
        props: { canViewBranchRules: false },
      });
      expect(findCodeOwnersActions().exists()).toBe(true);
    });

    it('when there are no codeowners but the user has access to branch rules the codeowner actions section is rendered', async () => {
      await createComponent({ codeOwnersDataMock: [], props: { canViewBranchRules: true } });
      expect(findCodeOwnersActions().exists()).toBe(true);
    });

    it('when the user does not have access to branch rules and there are no codeowners the codeowner actions section is not rendered', async () => {
      await createComponent({ codeOwnersDataMock: [], props: { canViewBranchRules: false } });
      expect(findCodeOwnersActions().exists()).toBe(false);
    });
  });

  describe('when no codeowners', () => {
    beforeEach(() => createComponent({ codeOwnersDataMock: [] }));

    it('renders no codeowners text', () => {
      expect(findNoCodeownersText().text()).toBe(i18n.noCodeOwnersText);
    });

    it('renders a link to docs page', () => {
      expect(findLinkToDocs().attributes('href')).toBe(codeOwnersHelpPath);
      expect(findLinkToDocs().attributes('target')).toBe('_blank');
    });

    it('does not render a popover trigger', () => {
      expect(findHelpPopoverTrigger().exists()).toBe(false);
    });

    it('does not render a popover', () => {
      expect(findHelpPopover().exists()).toBe(false);
    });
  });

  describe('link to branch settings', () => {
    it('does not render a link to branch rules settings for non-maintainers', async () => {
      await createComponent({ props: { canViewBranchRules: false } });
      expect(findBranchRulesLink().exists()).toBe(false);
    });

    it('renders a link to branch rules settings for users with maintainer access and higher', () => {
      expect(findBranchRulesLink().attributes('href')).toBe(codeOwnersPropsMock.branchRulesPath);
    });
  });

  it('with empty code owners, does not render code owners collapse', async () => {
    await createComponent({ codeOwnersDataMock: [] });

    expect(findCollapse().exists()).toBe(false);
  });

  it.each`
    codeOwners                    | expectedCount | expectedText
    ${codeOwnersMock.slice(0, 1)} | ${1}          | ${'Idella Welch'}
    ${codeOwnersMock.slice(0, 2)} | ${2}          | ${'Idella Welch and Winston Von'}
    ${codeOwnersMock.slice(0, 3)} | ${3}          | ${'Idella Welch, Winston Von, and Don Runte'}
    ${codeOwnersMock}             | ${7}          | ${toNounSeriesText(codeOwnersMock.map((x) => x.name))}
  `(
    'renders "$commaSeparators" comma separators, "$andSeparators" and separators for "$codeOwnersLength" codeowners',
    async ({ codeOwners, expectedCount, expectedText }) => {
      await createComponent({ codeOwnersDataMock: codeOwners });

      expect(findCollapse().text()).toBe(expectedText);
      expect(findCodeOwners()).toHaveLength(expectedCount);
    },
  );
});
