import Vue from 'vue';
import { convertObjectPropsToCamelCase } from '~/lib/utils/common_utils';
import { PQL_MODAL_ID } from 'ee/hand_raise_leads/hand_raise_lead/constants';
import apolloProvider from 'ee/subscriptions/graphql/graphql';
import HandRaiseLeadModal from './components/hand_raise_lead_modal.vue';

export default (function initHandRaiseLeadModal() {
  let handRaiseLeadModal;

  return () => {
    if (!handRaiseLeadModal) {
      const el = document.querySelector('.js-hand-raise-lead-modal');

      if (!el) {
        return false;
      }

      const { user, submitPath } = el.dataset;

      handRaiseLeadModal = new Vue({
        el,
        apolloProvider,
        name: 'HandRaiseLeadModalRoot',
        render: (createElement) =>
          createElement(HandRaiseLeadModal, {
            props: {
              user: convertObjectPropsToCamelCase(JSON.parse(user)),
              submitPath,
              modalId: PQL_MODAL_ID,
            },
          }),
      });
    }
    return handRaiseLeadModal;
  };
})();
