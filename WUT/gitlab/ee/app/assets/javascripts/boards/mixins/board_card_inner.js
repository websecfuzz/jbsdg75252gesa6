import { isNumber } from 'lodash';

export default {
  methods: {
    validIssueWeight(issue) {
      if (issue && isNumber(issue.weight)) {
        return issue.weight >= 0;
      }

      return false;
    },
  },
};
