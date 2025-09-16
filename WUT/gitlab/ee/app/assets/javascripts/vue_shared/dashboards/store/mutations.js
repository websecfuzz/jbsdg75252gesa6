import { createAlert, VARIANT_WARNING } from '~/alert';
import AccessorUtilities from '~/lib/utils/accessor';
import { parseIntPagination, normalizeHeaders } from '~/lib/utils/common_utils';
import { __ } from '~/locale';
import * as types from './mutation_types';

export const updatePageInfo = (state, headers) => {
  const { page, nextPage, total, totalPages } = parseIntPagination(normalizeHeaders(headers));
  const copy = { ...state.pageInfo };
  copy.currentPage = page;
  copy.nextPage = nextPage;
  copy.totalResults = total;
  copy.totalPages = totalPages;

  state.pageInfo = copy;
};

export default {
  [types.SET_PROJECT_ENDPOINT_LIST](state, url) {
    state.projectEndpoints.list = url;
  },
  [types.SET_PROJECT_ENDPOINT_ADD](state, url) {
    state.projectEndpoints.add = url;
  },
  [types.SET_PROJECTS](state, projects = []) {
    state.projects = projects;
    state.isLoadingProjects = false;
    if (AccessorUtilities.canUseLocalStorage()) {
      localStorage.setItem(
        state.projectEndpoints.list,
        state.projects.map((p) => p.id),
      );
    } else {
      createAlert({
        message: __('Project order will not be saved as local storage is not available.'),
        variant: VARIANT_WARNING,
      });
    }
  },
  [types.SET_SEARCH_QUERY](state, query) {
    state.searchQuery = query;
  },

  [types.SET_MESSAGE_MINIMUM_QUERY](state, bool) {
    state.messages.minimumQuery = bool;
  },

  [types.ADD_SELECTED_PROJECT](state, project) {
    if (!state.selectedProjects.some((p) => p.id === project.id)) {
      state.selectedProjects.push(project);
    }
  },
  [types.REMOVE_SELECTED_PROJECT](state, project) {
    state.selectedProjects = state.selectedProjects.filter((p) => p.id !== project.id);
  },

  [types.REQUEST_PROJECTS](state) {
    state.isLoadingProjects = true;
  },
  [types.RECEIVE_PROJECTS_SUCCESS](state, { projects, headers }) {
    let projectIds = [];
    if (AccessorUtilities.canUseLocalStorage()) {
      projectIds = (localStorage.getItem(state.projectEndpoints.list) || '').split(',');
    }
    // order Projects by ID, with any unassigned ones added to the end
    state.projects = projects.sort(
      (a, b) => projectIds.indexOf(a.id.toString()) - projectIds.indexOf(b.id.toString()),
    );
    state.isLoadingProjects = false;
    if (AccessorUtilities.canUseLocalStorage()) {
      localStorage.setItem(
        state.projectEndpoints.list,
        state.projects.map((p) => p.id),
      );
    }

    const pageInfo = parseIntPagination(normalizeHeaders(headers));
    state.projectsPage.pageInfo = pageInfo;
  },
  [types.RECEIVE_PROJECTS_ERROR](state) {
    state.projects = null;
    state.isLoadingProjects = false;
  },

  [types.CLEAR_SEARCH_RESULTS](state) {
    state.projectSearchResults = [];
    state.selectedProjects = [];
  },

  [types.REQUEST_SEARCH_RESULTS](state) {
    // Flipping this property separately to allows the UI
    // to hide the "minimum query" message
    // before the search results arrive from the API
    const copy = { ...state.messages };
    copy.minimumQuery = false;
    state.messages = copy;

    state.searchCount += 1;
  },
  [types.RECEIVE_NEXT_PAGE_SUCCESS](state, { data, headers }) {
    state.projectSearchResults = state.projectSearchResults.concat(data);
    updatePageInfo(state, headers);
  },
  [types.RECEIVE_SEARCH_RESULTS_SUCCESS](state, results) {
    state.projectSearchResults = results.data;
    const copy = { ...state.messages };
    copy.noResults = state.projectSearchResults.length === 0;
    copy.searchError = false;
    copy.minimumQuery = false;
    state.messages = copy;

    updatePageInfo(state, results.headers);

    state.searchCount = Math.max(0, state.searchCount - 1);
  },
  [types.RECEIVE_SEARCH_RESULTS_ERROR](state, message) {
    state.projectSearchResults = [];
    const copy = { ...state.messages };
    copy.noResults = false;
    copy.searchError = true;
    copy.minimumQuery = message === 'minimumQuery';
    state.messages = copy;

    state.searchCount = Math.max(0, state.searchCount - 1);
  },
  [types.MINIMUM_QUERY_MESSAGE](state) {
    state.projectSearchResults = [];
    state.pageInfo.totalResults = 0;
    const copy = { ...state.messages };
    copy.noResults = false;
    copy.searchError = false;
    copy.minimumQuery = true;
    state.messages = copy;

    state.searchCount = Math.max(0, state.searchCount - 1);
  },
};
