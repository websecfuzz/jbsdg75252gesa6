import apolloProvider from 'ee/subscriptions/graphql/graphql';
import CompanyForm from 'ee/registrations/components/company_form.vue';
import GlFieldErrors from '~/gl_field_errors';
import { initSimpleApp } from '~/helpers/init_simple_app_helper';

export default () => {
  initSimpleApp('#js-registrations-company-form', CompanyForm, {
    withApolloProvider: apolloProvider,
  });

  // Since we replaced form inputs, we need to re-initialize the field errors handler
  return new GlFieldErrors(document.querySelectorAll('.gl-show-field-errors'));
};
