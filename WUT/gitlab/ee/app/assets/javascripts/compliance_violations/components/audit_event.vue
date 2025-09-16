<script>
import { GlLink } from '@gitlab/ui';
import { humanize } from '~/lib/utils/text_utility';
import CrudComponent from '~/vue_shared/components/crud_component.vue';

export default {
  name: 'AuditEvent',
  components: {
    CrudComponent,
    GlLink,
  },
  props: {
    auditEvent: {
      type: Object,
      required: true,
    },
  },
  computed: {
    humanizedEventName() {
      return humanize(this.auditEvent.eventName || '');
    },
    authorName() {
      return this.auditEvent.author?.name || '';
    },
    ipAddress() {
      return this.auditEvent.ipAddress || '';
    },
    auditEntityType() {
      return this.auditEvent.entityType || '';
    },
  },
  methods: {
    openDrawer() {
      // This method will be implemented later to open a details drawer
    },
  },
};
</script>
<template>
  <crud-component>
    <template #title>
      {{ s__('ComplianceViolation|Audit event captured') }}
    </template>

    <template #default>
      <gl-link @click="openDrawer">
        {{ authorName }} - {{ humanizedEventName }}:
        {{ auditEntityType }}
      </gl-link>
      <div>
        {{ s__('ComplianceViolation|Registered event IP') }}:
        {{ ipAddress }}
      </div>
    </template>
  </crud-component>
</template>
