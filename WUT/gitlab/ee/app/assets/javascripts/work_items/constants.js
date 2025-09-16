import * as CE from '~/work_items/constants';

/*
 * We're disabling the import/export rule here because we want to
 * re-export the constants from the CE file while also overriding
 * anything that's EE-specific.
 */
/* eslint-disable import/export */
export * from '~/work_items/constants';

export const optimisticUserPermissions = {
  ...CE.optimisticUserPermissions,
  blockedWorkItems: true,
};

export const newWorkItemOptimisticUserPermissions = {
  ...CE.newWorkItemOptimisticUserPermissions,
  blockedWorkItems: true,
};
/* eslint-enable import/export */

/**
 * The default status colors in ee/app/models/work_items/statuses/system_defined/status.rb
 * do not provide enough color contrast in dark mode, so we are creating a map for each of the
 * to do, in progress, done, and won't do/duplicate colors to achieve color contrast better
 * than 3:1 in dark mode
 */
export const STATUS_LIGHT_TO_DARK_COLOR_MAP = {
  '#995715': '#D99530',
  '#737278': '#89888D',
  '#1f75cb': '#428FDC',
  '#108548': '#2DA160',
  '#DD2B0E': '#EC5941',
};
