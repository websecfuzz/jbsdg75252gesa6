/* eslint-disable no-new */

import $ from 'jquery';
import ProtectedBranchEdit from '~/protected_branches/protected_branch_edit';

export default class ProtectedBranchEditList {
  constructor(sectionSelector) {
    this.$wrap = $('.protected-branches-list');
    this.initEditForm(sectionSelector);
  }

  initEditForm(sectionSelector) {
    // Build edit forms
    this.$wrap.find('.js-protected-branch-edit-form').each((i, el) => {
      new ProtectedBranchEdit({
        $wrap: $(el),
        hasLicense: true,
        sectionSelector,
      });
    });
  }
}
