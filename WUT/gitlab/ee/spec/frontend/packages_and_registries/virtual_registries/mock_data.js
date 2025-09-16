export const mockCacheEntries = [
  {
    id: 'NSAvdGVzdC9iYXI=',
    group_id: 209,
    upstream_id: 5,
    upstream_checked_at: '2025-05-19T14:22:23.048Z',
    file_md5: null,
    file_sha1: '4e1243bd22c66e76c2ba9eddc1f91394e57f9f83',
    size: 15,
    relative_path: '/test/bar',
    upstream_etag: null,
    content_type: 'application/octet-stream',
    created_at: '2025-05-19T14:22:23.050Z',
    updated_at: '2025-05-19T14:22:23.050Z',
  },
];

export const mockUpstream = {
  id: 5,
  name: 'Upstream Registry',
  url: 'https://gitlab.com/groups/gitlab-org/maven',
  description: 'Upstream registry description',
  cacheEntriesCount: 1,
};

export const mockUpstreamPagination = {
  id: 5,
  name: 'Upstream Registry',
  url: 'https://gitlab.com/groups/gitlab-org/maven',
  description: 'Upstream registry description',
  cacheEntriesCount: 22,
};

export const groupVirtualRegistry = {
  group: {
    id: 'gid://gitlab/Group/33',
    __typename: 'Group',
    mavenVirtualRegistries: {
      __typename: 'MavenVirtualRegistryConnection',
      nodes: [
        {
          __typename: 'MavenVirtualRegistry',
          id: 'gid://gitlab/VirtualRegistries::Packages::Maven::Registry/2',
          name: 'Maven Registry 1',
          description: '',
          upstreams: [
            {
              __typename: 'MavenUpstream',
              id: 'gid://gitlab/VirtualRegistries::Packages::Maven::Upstream/2',
              cacheValidityHours: 24,
              name: 'Maven upstream',
              description: 'Maven Central',
              username: '',
              password: '',
              url: 'https://repo.maven.apache.org/maven2',
              registryUpstreams: [
                {
                  __typename: 'MavenRegistryUpstream',

                  id: 'gid://gitlab/VirtualRegistries::Packages::Maven::RegistryUpstream/2',
                  position: 1,
                },
              ],
            },
            {
              __typename: 'MavenUpstream',
              id: 'gid://gitlab/VirtualRegistries::Packages::Maven::Upstream/5',
              cacheValidityHours: 24,
              name: 'Maven upstream 4',
              description: null,
              username: null,
              password: null,
              url: 'https://repo.maven.apache.org/maven2',
              registryUpstreams: [
                {
                  __typename: 'MavenRegistryUpstream',
                  id: 'gid://gitlab/VirtualRegistries::Packages::Maven::RegistryUpstream/3',
                  position: 2,
                },
              ],
            },
            {
              __typename: 'MavenUpstream',
              id: 'gid://gitlab/VirtualRegistries::Packages::Maven::Upstream/6',
              cacheValidityHours: 24,
              name: 'Maven upstream 4',
              description: null,
              username: null,
              password: null,
              url: 'https://repo.maven.apache.org/maven2',
              registryUpstreams: [
                {
                  __typename: 'MavenRegistryUpstream',
                  id: 'gid://gitlab/VirtualRegistries::Packages::Maven::RegistryUpstream/4',
                  position: 3,
                },
              ],
            },
            {
              __typename: 'MavenUpstream',
              id: 'gid://gitlab/VirtualRegistries::Packages::Maven::Upstream/7',
              cacheValidityHours: 24,
              name: 'Maven upstream 4',
              description: null,
              username: null,
              password: null,
              url: 'https://repo.maven.apache.org/maven2',
              registryUpstreams: [
                {
                  __typename: 'MavenRegistryUpstream',
                  id: 'gid://gitlab/VirtualRegistries::Packages::Maven::RegistryUpstream/7',
                  position: 4,
                },
              ],
            },
          ],
        },
      ],
    },
  },
};
