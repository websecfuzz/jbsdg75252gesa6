import Vue from 'vue';
import { IDE_ELEMENT_ID } from '~/ide/constants';
import Translate from '~/vue_shared/translate';
import { OAuthCallbackDomainMismatchErrorApp } from './oauth_callback_domain_mismatch_error';

Vue.use(Translate);

/**
 * Start the IDE.
 *
 * @param {Objects} options - Extra options for the IDE (Used by EE).
 */
export async function startIde() {
  const ideElement = document.getElementById(IDE_ELEMENT_ID);

  if (!ideElement) {
    return;
  }

  const oAuthCallbackDomainMismatchApp = new OAuthCallbackDomainMismatchErrorApp(ideElement);

  if (oAuthCallbackDomainMismatchApp.shouldRenderError()) {
    oAuthCallbackDomainMismatchApp.renderError();
    return;
  }
  const { initGitlabWebIDE } = await import('./init_gitlab_web_ide');
  initGitlabWebIDE(ideElement);
}
