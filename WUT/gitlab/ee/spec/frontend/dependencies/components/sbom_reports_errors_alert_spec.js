import { GlAccordion, GlAccordionItem, GlSprintf } from '@gitlab/ui';
import HelpPageLink from '~/vue_shared/components/help_page_link/help_page_link.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import SbomReportsErrorsAlert from 'ee/dependencies/components/sbom_reports_errors_alert.vue';

const TEST_ERRORS = [
  ['Unsupported CycloneDX spec version. Must be one of: 1.4, 1.5'],
  ['Invalid CycloneDX report: property "/metadata/tools/0"', 'Some other error'],
];

describe('SbomReportsErrorsAlert component', () => {
  let wrapper;

  const createWrapper = ({ propsData } = {}) =>
    shallowMountExtended(SbomReportsErrorsAlert, {
      propsData: {
        errors: TEST_ERRORS,
        ...propsData,
      },
      stubs: {
        GlSprintf,
      },
    });

  const findHelpPageLink = () => wrapper.findComponent(HelpPageLink);
  const findAccordion = () => wrapper.findComponent(GlAccordion);
  const findAllAccordionItems = () => wrapper.findAllComponents(GlAccordionItem);
  const findAccordionItemWithTitle = (title) =>
    findAllAccordionItems().wrappers.find((item) => item.props('title') === title);
  const findErrorList = () => wrapper.findByRole('list');
  const findSbomErrorDescription = () => wrapper.findByTestId('sbom-error-description');

  beforeEach(() => {
    wrapper = createWrapper();
  });

  it('links to the SBOM report documentation', () => {
    expect(findHelpPageLink().props()).toEqual({
      href: 'user/application_security/dependency_list/_index',
      anchor: 'set-up-the-dependency-list',
    });
  });

  describe('error description text', () => {
    it('renders the value provided via the props', () => {
      wrapper = createWrapper({ propsData: { errorDescription: 'custom description' } });

      expect(findSbomErrorDescription().text()).toBe('custom description');
    });

    it('renders the default value when none is provided', () => {
      const defaultDescription =
        'The following SBOM reports could not be parsed. Therefore the list of components may be incomplete.';

      expect(findSbomErrorDescription().text()).toBe(defaultDescription);
    });
  });

  describe('alert details', () => {
    it('shows an accordion containing a list of reports with errors', () => {
      expect(findAccordion().exists()).toBe(true);
      expect(findAllAccordionItems()).toHaveLength(TEST_ERRORS.length);
    });

    it('shows a list containing details about each message', () => {
      expect(findErrorList().exists()).toBe(true);
    });

    describe.each`
      errors            | title
      ${TEST_ERRORS[0]} | ${'report-1 (1)'}
      ${TEST_ERRORS[1]} | ${'report-2 (2)'}
    `('when errors are $errors', ({ errors, title }) => {
      it('contains an accordion item with the correct title', () => {
        expect(findAccordionItemWithTitle(title).exists()).toBe(true);
      });

      it('contains a detailed list of errors', () => {
        const expectedErrors = findAccordionItemWithTitle(title)
          .findAll('li')
          .wrappers.map((w) => w.text());

        expect(expectedErrors).toStrictEqual(errors);
      });
    });
  });
});
