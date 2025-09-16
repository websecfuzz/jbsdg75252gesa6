<script>
import { s__ } from '~/locale';

export default {
  i18n: {
    title: s__('ScanResultPolicy|Groups'),
  },
  name: 'GroupsSelector',
};
</script>

<template>
  <div>{{ $options.i18n.title }}</div>
</template>
