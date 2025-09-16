import axios from '~/lib/utils/axios_utils';
import eventHub from '~/projects/new/event_hub';
import projectNew from '~/projects/project_new';
import { sanitize } from '~/lib/dompurify';

const INSTANCE_TAB_CONTENT_SELECTOR = '.js-custom-instance-project-templates-tab-content';
const GROUP_TAB_CONTENT_SELECTOR = '.js-custom-group-project-templates-tab-content';

const bindEvents = () => {
  const useCustomTemplateBtn = document.querySelectorAll('.custom-template-button > input');
  const projectTemplateButtons = document.querySelectorAll('.project-templates-buttons');

  const projectFieldsForm = document.querySelector('.project-fields-form');
  const selectedIcon = document.querySelector('.selected-icon');
  const selectedTemplateText = document.querySelector('.selected-template');
  const templateProjectNameInput = document.querySelector('#template-project-name #project_path');
  const changeTemplateBtn = document.querySelector('.change-template');
  const projectFieldsFormInput = document.querySelector(
    '.project-fields-form input#project_use_custom_template',
  );
  const subgroupWithTemplatesIdInput = document.querySelector(
    '.js-project-group-with-project-templates-id',
  );

  const pagination = document.querySelector('.gl-pagination');
  let hasUserDefinedProjectName = false;

  if (useCustomTemplateBtn.length === 0) {
    return;
  }

  function enableCustomTemplate() {
    projectFieldsFormInput.value = true;
  }

  function disableCustomTemplate() {
    projectFieldsFormInput.value = false;
  }

  function chooseTemplate(e) {
    const el = e.currentTarget;
    const { subgroupId, parentGroupId, templateName } = el.dataset;

    const activeTabProjectName = document.querySelector('.tab-pane.active #project_name');
    const activeTabProjectPath = document.querySelector('.tab-pane.active #project_path');
    const clonedTemplate = el
      .closest('.template-option')
      .querySelector('.gl-avatar')
      .cloneNode(true);

    if (subgroupId) {
      const { subgroupFullPath, targetGroupFullPath } = el.dataset;
      eventHub.$emit(
        'select-template',
        targetGroupFullPath ? parentGroupId : null,
        targetGroupFullPath || subgroupFullPath,
      );

      subgroupWithTemplatesIdInput.value = subgroupId;
    }

    projectTemplateButtons.forEach((btn) => {
      btn.classList.add('hidden');
    });
    projectFieldsForm.classList.add('selected');

    selectedIcon.innerHTML = '';
    selectedTemplateText.textContent = templateName;

    clonedTemplate.classList.replace('s40', '!gl-block');
    selectedIcon.append(clonedTemplate);

    templateProjectNameInput.focus();
    enableCustomTemplate();

    activeTabProjectName.focus();
    activeTabProjectName.addEventListener('keyup', () => {
      projectNew.onProjectNameChange(activeTabProjectName, activeTabProjectPath);
      hasUserDefinedProjectName = activeTabProjectName.value.trim().length > 0;
    });
    activeTabProjectPath.addEventListener('keyup', () =>
      projectNew.onProjectPathChange(
        activeTabProjectName,
        activeTabProjectPath,
        hasUserDefinedProjectName,
      ),
    );
  }

  useCustomTemplateBtn.forEach((btn) => {
    btn.addEventListener('change', (e) => {
      chooseTemplate(e);
    });
  });

  changeTemplateBtn.addEventListener('click', () => {
    projectTemplateButtons.forEach((btn) => {
      btn.classList.remove('hidden');
    });

    useCustomTemplateBtn.forEach((btn) => {
      // eslint-disable-next-line no-param-reassign
      btn.checked = false;
    });

    disableCustomTemplate();
  });

  pagination?.addEventListener('ajax:success', (event) => {
    const tabContent = pagination.closest(
      [INSTANCE_TAB_CONTENT_SELECTOR, GROUP_TAB_CONTENT_SELECTOR].join(','),
    );
    const doc = event.detail[0];
    const element = document.adoptNode(doc.body.firstElementChild);

    tabContent.innerHTML = '';
    tabContent.append(element);
    bindEvents();
  });

  document.querySelectorAll('.js-template-group-options').forEach((tmplEl) => {
    tmplEl.addEventListener('click', (el) => {
      el.currentTarget.classList.toggle('expanded');
    });
  });

  document.querySelector('.js-create-project-button').addEventListener('click', (e) => {
    projectNew.validateGroupNamespaceDropdown(e);
  });
};

export default () => {
  const navElement = document.querySelector('.js-custom-instance-project-templates-nav-link');
  const tabContent = document.querySelector(INSTANCE_TAB_CONTENT_SELECTOR);
  const groupNavElement = document.querySelector('.js-custom-group-project-templates-nav-link');
  const groupTabContent = document.querySelector(GROUP_TAB_CONTENT_SELECTOR);
  const findActiveTab = (selector) => document.querySelector(`${selector}.active`);
  const findPagination = (selector) => findActiveTab(selector)?.querySelector('.gl-pagination');

  const initPagination = (handler) => {
    // This is a temporary workaround as part of a P1 bug fix
    // In a future iteration the pagination should be implemented on the frontend
    const pagination =
      findPagination(INSTANCE_TAB_CONTENT_SELECTOR) || findPagination(GROUP_TAB_CONTENT_SELECTOR);
    if (!pagination) return;

    pagination.querySelectorAll('a').forEach((anchor) => anchor.addEventListener('click', handler));
  };

  const handlePaginate = async (e) => {
    e.preventDefault();
    const response = await axios.get(e.currentTarget.href);
    const secureContent = sanitize(response.data);
    const activeTabContent =
      findActiveTab(INSTANCE_TAB_CONTENT_SELECTOR) || findActiveTab(GROUP_TAB_CONTENT_SELECTOR);

    activeTabContent.innerHTML = secureContent;
    initPagination(handlePaginate);
    bindEvents();
  };

  const fetchHtmlForTabContent = async (content) => {
    const response = await axios.get(content.dataset.initialTemplates);
    const secureContent = sanitize(response.data);
    // eslint-disable-next-line no-param-reassign
    content.innerHTML = secureContent;
    initPagination(handlePaginate);
    bindEvents();
  };

  navElement?.addEventListener('click', () => fetchHtmlForTabContent(tabContent), { once: true });
  groupNavElement?.addEventListener('click', () => fetchHtmlForTabContent(groupTabContent), {
    once: true,
  });

  bindEvents();
};
