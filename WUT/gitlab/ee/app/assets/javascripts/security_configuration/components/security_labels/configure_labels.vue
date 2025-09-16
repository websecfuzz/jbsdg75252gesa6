<script>
import getSecurityLabelsQuery from '../../graphql/client/security_labels.query.graphql';
import CategoryList from './category_list.vue';
import CategoryForm from './category_form.vue';
import LabelDrawer from './label_drawer.vue';
import { defaultCategory } from './constants';

export default {
  components: {
    CategoryList,
    CategoryForm,
    LabelDrawer,
  },
  inject: ['groupFullPath'],
  data() {
    return {
      group: {
        securityLabelCategories: { nodes: [] },
        securityLabels: { nodes: [] },
      },
      selectedCategory: null,
    };
  },
  apollo: {
    group: {
      query: getSecurityLabelsQuery,
      variables() {
        return {
          fullPath: this.groupFullPath,
          categoryId: this.selectedCategory?.id,
        };
      },
      result({ data }) {
        if (!this.selectedCategory && data.group.securityLabelCategories.nodes.length) {
          this.selectCategory(data.group.securityLabelCategories.nodes[0]);
        }
      },
    },
  },
  methods: {
    selectCategory(category) {
      this.selectedCategory = {
        ...defaultCategory,
        ...category,
      };
    },
    openDrawer(mode, item) {
      this.$refs.labelDrawer.open(mode, item);
    },
    editLabel(label) {
      this.openDrawer('edit', label);
    },
    addLabel() {
      this.openDrawer('add');
    },
    onSubmit(item) {
      // eslint-disable-next-line no-console
      console.log(item);
    },
    onDelete(item) {
      // eslint-disable-next-line no-console
      console.log(item);
    },
  },
};
</script>
<template>
  <div class="gl-border-t gl-flex">
    <div class="gl-border-r gl-w-1/4 gl-p-5">
      <category-list
        :security-label-categories="group.securityLabelCategories.nodes"
        :selected-category="selectedCategory"
        @selectCategory="selectCategory"
      />
    </div>
    <div class="gl-w-3/4">
      <category-form
        :security-labels="group.securityLabels.nodes"
        :category="selectedCategory"
        @addLabel="addLabel"
        @editLabel="editLabel"
      />
      <label-drawer ref="labelDrawer" @saved="onSubmit" @delete="onDelete" />
    </div>
  </div>
</template>
