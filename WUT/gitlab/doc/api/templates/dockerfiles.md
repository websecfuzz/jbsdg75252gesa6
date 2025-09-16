---
stage: Create
group: Source Code
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments
title: Dockerfiles API
---

{{< details >}}

- Tier: Free, Premium, Ultimate
- Offering: GitLab.com, GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

GitLab provides an API endpoint for Dockerfile templates available to the entire instance.
Default templates are defined at
[`vendor/Dockerfile`](https://gitlab.com/gitlab-org/gitlab-foss/-/tree/master/vendor/Dockerfile)
in the GitLab repository.

Users with the Guest role can't access the Dockerfiles templates. For more information, see [Project and group visibility](../../user/public_access.md).

## Override Dockerfile API templates

{{< details >}}

- Tier: Premium, Ultimate
- Offering: GitLab Self-Managed, GitLab Dedicated

{{< /details >}}

In [GitLab Premium and Ultimate](https://about.gitlab.com/pricing/) tiers, GitLab instance
administrators can override templates in the
[**Admin** area](../../administration/settings/instance_template_repository.md).

## List Dockerfile templates

Get all Dockerfile templates.

```plaintext
GET /templates/dockerfiles
```

Example request:

```shell
curl "https://gitlab.example.com/api/v4/templates/dockerfiles"
```

Example response:

```json
[
  {
    "key": "Binary",
    "name": "Binary"
  },
  {
    "key": "Binary-alpine",
    "name": "Binary-alpine"
  },
  {
    "key": "Binary-scratch",
    "name": "Binary-scratch"
  },
  {
    "key": "Golang",
    "name": "Golang"
  },
  {
    "key": "Golang-alpine",
    "name": "Golang-alpine"
  },
  {
    "key": "Golang-scratch",
    "name": "Golang-scratch"
  },
  {
    "key": "HTTPd",
    "name": "HTTPd"
  },
  {
    "key": "Node",
    "name": "Node"
  },
  {
    "key": "Node-alpine",
    "name": "Node-alpine"
  },
  {
    "key": "OpenJDK",
    "name": "OpenJDK"
  },
  {
    "key": "PHP",
    "name": "PHP"
  },
  {
    "key": "Python",
    "name": "Python"
  },
  {
    "key": "Python-alpine",
    "name": "Python-alpine"
  },
  {
    "key": "Python2",
    "name": "Python2"
  },
  {
    "key": "Ruby",
    "name": "Ruby"
  },
  {
    "key": "Ruby-alpine",
    "name": "Ruby-alpine"
  },
  {
    "key": "Rust",
    "name": "Rust"
  },
  {
    "key": "Swift",
    "name": "Swift"
  }
]
```

## Single Dockerfile template

Get a single Dockerfile template.

```plaintext
GET /templates/dockerfiles/:key
```

| Attribute | Type   | Required | Description |
|-----------|--------|----------|-------------|
| `key`     | string | yes      | The key of the Dockerfile template |

Example request:

```shell
curl "https://gitlab.example.com/api/v4/templates/dockerfiles/Binary"
```

Example response:

```json
{
  "name": "Binary",
  "content": "# This file is a template, and might need editing before it works on your project.\n# This Dockerfile installs a compiled binary into a bare system.\n# You must either commit your compiled binary into source control (not recommended)\n# or build the binary first as part of a CI/CD pipeline.\n\nFROM buildpack-deps:buster\n\nWORKDIR /usr/local/bin\n\n# Change `app` to whatever your binary is called\nAdd app .\nCMD [\"./app\"]\n"
}
```
