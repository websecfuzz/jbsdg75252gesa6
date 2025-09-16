import Vue from 'vue';
// eslint-disable-next-line no-restricted-imports
import Vuex from 'vuex';
import * as actions from './actions';
import * as getters from './getters';
import mutations from './mutations';
import createState from './state';

Vue.use(Vuex);

export const createStore = (initialState = {}) =>
  new Vuex.Store({
    actions,
    getters,
    mutations,
    state: createState(initialState),
  });
