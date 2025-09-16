import { helpPagePath } from '~/helpers/help_page_helper';

export const SELECTIVE_SYNC_SHARDS = 'selectiveSyncShards';
export const SELECTIVE_SYNC_NAMESPACES = 'selectiveSyncNamespaceIds';
export const VALIDATION_FIELD_KEYS = {
  NAME: 'name',
  URL: 'url',
  REPOS_MAX_CAPACITY: 'reposMaxCapacity',
  FILES_MAX_CAPACITY: 'filesMaxCapacity',
  CONTAINER_REPOSITORIES_MAX_CAPACITY: 'containerRepositoriesMaxCapacity',
  VERIFICATION_MAX_CAPACITY: 'verificationMaxCapacity',
  MINIMUM_REVERIFICATION_INTERVAL: 'minimumReverificationInterval',
};

export const PRIMARY_SITE_SETTINGS = helpPagePath('administration/geo_sites.html', {
  anchor: 'common-settings',
});

export const SECONDARY_SITE_SETTINGS = helpPagePath('administration/geo_sites.html', {
  anchor: 'secondary-site-settings',
});

export const SELECTIVE_SYNC_MORE_INFO = helpPagePath(
  'administration/geo/replication/selective_synchronization',
);

export const OBJECT_STORAGE_MORE_INFO = helpPagePath(
  'administration/geo/replication/object_storage.html',
);

export const REVERIFICATION_MORE_INFO = helpPagePath(
  'administration/geo/disaster_recovery/background_verification.html',
  { anchor: 'repository-re-verification' },
);

export const BACKFILL_MORE_INFO = helpPagePath('administration/geo_sites.html', {
  anchor: 'geo-backfill',
});
