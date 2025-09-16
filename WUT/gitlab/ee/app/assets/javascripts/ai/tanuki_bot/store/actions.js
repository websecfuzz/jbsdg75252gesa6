import { GENIE_CHAT_MODEL_ROLES } from 'ee/ai/constants';
import * as types from './mutation_types';

const proxyMessageContent = (message, propsToUpdate) => {
  return {
    ...message,
    ...propsToUpdate,
    role: message.role || GENIE_CHAT_MODEL_ROLES.user,
  };
};

export const addDuoChatMessage = async ({ commit }, messageData = { content: '' }) => {
  const { errors = [], content = '' } = messageData || {};
  const msgContent = content || errors.join('; ');

  if (msgContent) {
    const message = proxyMessageContent(messageData, { content: msgContent });

    if (message.role.toLowerCase() === GENIE_CHAT_MODEL_ROLES.system) {
      commit(types.ADD_TOOL_MESSAGE, message);
    } else {
      commit(types.ADD_MESSAGE, message);
    }
  }
};

export const setMessages = ({ dispatch, commit }, messages = []) => {
  if (messages.length) {
    messages.forEach((msg) => {
      dispatch('addDuoChatMessage', msg);
    });
  } else {
    commit(types.CLEAN_MESSAGES);
  }
};

export const setLoading = ({ commit }, flag = true) => {
  commit(types.SET_LOADING, flag);
};
