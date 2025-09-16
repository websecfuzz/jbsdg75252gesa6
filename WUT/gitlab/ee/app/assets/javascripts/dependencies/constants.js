import { s__ } from '~/locale';

export const NAMESPACE_PROJECT = 'project';
export const NAMESPACE_GROUP = 'group';
export const NAMESPACE_ORGANIZATION = 'organization';

export const EXPORT_FORMAT_CSV = 'csv';
export const EXPORT_FORMAT_DEPENDENCY_LIST = 'dependency_list';
export const EXPORT_FORMAT_JSON_ARRAY = 'json_array';
export const EXPORT_FORMAT_CYCLONEDX_1_6_JSON = 'cyclonedx_1_6_json';

export const DEPENDENCIES_TABLE_I18N = {
  component: s__('Dependencies|Component'),
  packager: s__('Dependencies|Packager'),
  location: s__('Dependencies|Location'),
  unknown: s__('Dependencies|unknown'),
  license: s__('Dependencies|License'),
  projects: s__('Dependencies|Projects'),
  vulnerabilities: s__('Dependencies|Vulnerabilities'),
  tooltipText: s__(
    'Dependencies|Locations of dependencies. The locations of transitive dependencies (child dependencies of other dependencies) are shown as the complete set of all paths that import the dependency.',
  ),
  tooltipMoreText: s__('Dependencies|Learn more about direct dependents'),
  locationDependencyTitle: s__('Dependencies|List of direct dependents'),
  toggleVulnerabilityList: s__('Dependencies|Toggle vulnerability list'),
  dependencyPathButtonText: s__('Dependencies|View dependency paths'),
};
