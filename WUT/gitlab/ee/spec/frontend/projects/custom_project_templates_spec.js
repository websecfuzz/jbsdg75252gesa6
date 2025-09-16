import MockAdapter from 'axios-mock-adapter';
import { setHTMLFixture, resetHTMLFixture } from 'helpers/fixtures';
import axios from '~/lib/utils/axios_utils';
import { HTTP_STATUS_OK } from '~/lib/utils/http_status';
import { TEST_HOST } from 'helpers/test_constants';
import waitForPromises from 'helpers/wait_for_promises';
import initCustomProjectTemplates from 'ee/projects/custom_project_templates';

const INSTANCE_TEMPLATES_ENDPOINT = `${TEST_HOST}/users/root/available_instance_templates`;
const INSTANCE_TAB_LINK_SELECTOR = '.js-custom-instance-project-templates-nav-link';
const INSTANCE_TAB_CONTENT_SELECTOR = '.js-custom-instance-project-templates-tab-content';

const GROUP_TEMPLATES_ENDPOINT = `${TEST_HOST}/users/root/available_group_templates`;
const GROUP_TAB_LINK_SELECTOR = '.js-custom-group-project-templates-nav-link';
const GROUP_TAB_CONTENT_SELECTOR = '.js-custom-group-project-templates-tab-content';

const INITIAL_CONTENT = 'initial content';
const NEXT_PAGE_CONTENT = 'page 2 content';

const generateInstanceTabContent = (content) => {
  return `
      <div class="js-custom-instance-project-templates-nav-link">Instance tab</div>
      <div class="js-custom-instance-project-templates-tab-content active" data-initial-templates="${INSTANCE_TEMPLATES_ENDPOINT}">
          ${content}
          <ul class="gl-pagination">
              <li><a href="/users/root/available_instance_templates">Prev</a></li>
              <li><a href="/users/root/available_instance_templates">1</a></li>
              <li><a href="/users/root/available_instance_templates?page=2" class="page-2">2</a></li>
              <li><a href="#" class="page-link" rel="next">Next</a></li>
          </ul>
      </div>
  `;
};

const generateGroupTabContent = (content) => {
  return `
      <div class="js-custom-group-project-templates-nav-link">Group tab</div>
      <div class="js-custom-group-project-templates-tab-content active" data-initial-templates="${GROUP_TEMPLATES_ENDPOINT}">
          ${content}
          <ul class="gl-pagination">
              <li><a href="/users/root/available_group_templates">Prev</a></li>
              <li><a href="/users/root/available_group_templates">1</a></li>
              <li><a href="/users/root/available_group_templates?page=2" class="page-2">2</a></li>
              <li><a href="#" class="page-link" rel="next">Next</a></li>
          </ul>
      </div>
  `;
};

describe('initCustomProjectTemplates', () => {
  const simulatePagination = () => document.querySelector('.page-2').click();

  describe.each`
    tabName       | contentGenerator              | navLinkSelector               | contentSelector                  | endpoint
    ${'Instance'} | ${generateInstanceTabContent} | ${INSTANCE_TAB_LINK_SELECTOR} | ${INSTANCE_TAB_CONTENT_SELECTOR} | ${INSTANCE_TEMPLATES_ENDPOINT}
    ${'Group'}    | ${generateGroupTabContent}    | ${GROUP_TAB_LINK_SELECTOR}    | ${GROUP_TAB_CONTENT_SELECTOR}    | ${GROUP_TEMPLATES_ENDPOINT}
  `(
    '($tabName tab) requests the correct content',
    ({ contentGenerator, navLinkSelector, contentSelector, endpoint }) => {
      const simulateTabNavigation = () => document.querySelector(navLinkSelector).click();
      const findTabContent = () => document.querySelector(contentSelector);

      beforeEach(async () => {
        const axiosMock = new MockAdapter(axios);

        axiosMock.onGet(endpoint).reply(HTTP_STATUS_OK, contentGenerator(INITIAL_CONTENT));
        axiosMock
          .onGet(`${endpoint}?page=2`)
          .reply(HTTP_STATUS_OK, contentGenerator(NEXT_PAGE_CONTENT));

        setHTMLFixture(contentGenerator());
        initCustomProjectTemplates();
        simulateTabNavigation();
        await waitForPromises();
      });

      afterEach(() => resetHTMLFixture());

      it('requests the initial content', () => {
        expect(findTabContent().innerText).toContain(INITIAL_CONTENT);
      });

      it('requests content for the selected page', async () => {
        simulatePagination();
        await waitForPromises();

        expect(findTabContent().innerText).toContain(NEXT_PAGE_CONTENT);
      });
    },
  );
});
