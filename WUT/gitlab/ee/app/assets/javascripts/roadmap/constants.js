import { s__, __ } from '~/locale';

/*
  Update the counterparts in roadmap.scss when making changes.
*/

// Counterpart: $details-cell-width in roadmap.scss
export const EPIC_DETAILS_CELL_WIDTH = 320;

// Counterpart: $item-height in roadmap.scss
export const EPIC_ITEM_HEIGHT = 50;

// Counterpart: $timeline-cell-width in roadmap.scss
export const TIMELINE_CELL_MIN_WIDTH = 180;

export const SCROLL_BAR_SIZE = 16;

export const EPIC_HIGHLIGHT_REMOVE_AFTER = 3000;

export const DAYS_IN_WEEK = 7;

export const PERCENTAGE = 100;

export const SMALL_TIMELINE_BAR = 40;

export const DATE_RANGES = {
  CURRENT_QUARTER: 'CURRENT_QUARTER',
  CURRENT_YEAR: 'CURRENT_YEAR',
  THREE_YEARS: 'THREE_YEARS',
};

export const PRESET_TYPES = {
  QUARTERS: 'QUARTERS',
  MONTHS: 'MONTHS',
  WEEKS: 'WEEKS',
};

export const emptyStateDefault = s__(
  'GroupRoadmap|To view the roadmap, add a start or due date to one of your epics in this group or its subgroups; from %{dateRange}.',
);

export const emptyStateWithFilters = s__(
  'GroupRoadmap|To widen your search, change or remove filters; from %{dateRange}.',
);

export const emptyStateWithEpicIidFiltered = s__(
  'GroupRoadmap|To make your epics appear in the roadmap, add start or due dates to them.',
);

export const EPIC_LEVEL_MARGIN = {
  1: 'gl-ml-3',
  2: 'gl-ml-5',
  3: 'gl-ml-6',
  4: 'gl-ml-7',
  5: 'gl-ml-8',
  6: 'gl-ml-9',
};

export const ROADMAP_PAGE_SIZE = 50;

export const PROGRESS_WEIGHT = 'WEIGHT';
export const PROGRESS_COUNT = 'COUNT';

export const PROGRESS_TRACKING_OPTIONS = [
  { text: __('Use issue weight'), value: PROGRESS_WEIGHT },
  { text: __('Use issue count'), value: PROGRESS_COUNT },
];

export const UNSUPPORTED_ROADMAP_PARAMS = [
  'scope',
  'utf8',
  'state',
  'sort',
  'timeframe_range_type',
  'layout',
  'progress',
];

export const ALLOWED_SORT_VALUES = [
  'START_DATE_ASC',
  'START_DATE_DESC',
  'END_DATE_ASC',
  'END_DATE_DESC',
  'TITLE_ASC',
  'TITLE_DESC',
  'CREATED_AT_ASC',
  'CREATED_AT_DESC',
  'UPDATED_AT_ASC',
  'UPDATED_AT_DESC',
];

export const MILESTONES_ALL = 'ALL';
export const MILESTONES_GROUP = 'GROUP';
export const MILESTONES_SUBGROUP = 'SUBGROUP';
export const MILESTONES_PROJECT = 'PROJECT';

export const MILESTONES_OPTIONS = [
  { text: __('Show all milestones'), value: MILESTONES_ALL },
  { text: __('Show group milestones'), value: MILESTONES_GROUP },
  { text: __('Show sub-group milestones'), value: MILESTONES_SUBGROUP },
  { text: __('Show project milestones'), value: MILESTONES_PROJECT },
];
