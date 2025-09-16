import axios from '~/lib/utils/axios_utils';
import { shouldQrtlyReconciliationMount } from 'ee/billings/qrtly_reconciliation';
import initSubscriptions from 'ee/billings/subscriptions';
import { createAlert } from '~/alert';
import { __ } from '~/locale';

initSubscriptions();
shouldQrtlyReconciliationMount();

const dismissTargetedMessage = (e) => {
  e.preventDefault();

  const targetedMessage = e.currentTarget.closest('.js-targeted-message');
  const ds = targetedMessage.dataset;

  if (!ds.targetedMessageId) return;

  targetedMessage.remove();

  axios
    .post(ds.dismissEndpoint, {
      targeted_message_id: ds.targetedMessageId,
      namespace_id: ds.namespaceId,
    })
    .catch(() => {
      createAlert({
        message: __(
          'An error occurred while dismissing the alert. Refresh the page and try again.',
        ),
      });
    });
};

document
  .querySelectorAll('.js-targeted-message .js-close')
  .forEach((close) => close.addEventListener('click', dismissTargetedMessage));
