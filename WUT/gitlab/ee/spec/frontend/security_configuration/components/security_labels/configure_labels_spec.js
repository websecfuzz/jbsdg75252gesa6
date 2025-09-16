import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMount } from '@vue/test-utils';
import ConfigureLabels from 'ee/security_configuration/components/security_labels/configure_labels.vue';
import CategoryList from 'ee/security_configuration/components/security_labels/category_list.vue';
import CategoryForm from 'ee/security_configuration/components/security_labels/category_form.vue';
import createMockApollo from 'helpers/mock_apollo_helper';
import getSecurityLabelsQuery from 'ee/security_configuration/graphql/client/security_labels.query.graphql';
import waitForPromises from 'helpers/wait_for_promises';
import {
  mockSecurityLabelCategories,
  mockSecurityLabels,
} from 'ee/security_configuration/graphql/resolvers';

Vue.use(VueApollo);

const firstCategory = mockSecurityLabelCategories[0];
const secondCategory = mockSecurityLabelCategories[1];

describe('Configure labels', () => {
  let wrapper;

  const queryHandler = jest.fn().mockResolvedValue({
    data: {
      group: {
        id: 'gid://gitlab/Group/group',
        securityLabelCategories: { nodes: mockSecurityLabelCategories },
        securityLabels: { nodes: mockSecurityLabels },
      },
    },
  });

  const createComponent = (requestHandlers = [[getSecurityLabelsQuery, queryHandler]]) => {
    const apolloProvider = createMockApollo(requestHandlers, [], {
      typePolicies: {
        Query: {
          fields: {
            group: {
              merge: true,
            },
          },
        },
      },
    });
    wrapper = shallowMount(ConfigureLabels, {
      provide: { groupFullPath: 'path/to/group' },
      apolloProvider,
    });
  };

  beforeEach(async () => {
    createComponent();
    await waitForPromises();
  });

  it('queries for the security label categories', () => {
    expect(queryHandler).toHaveBeenCalledWith({
      categoryId: undefined,
      fullPath: 'path/to/group',
    });
  });

  it('renders the list of categories', () => {
    expect(wrapper.findComponent(CategoryList).props()).toStrictEqual({
      securityLabelCategories: mockSecurityLabelCategories,
      selectedCategory: firstCategory,
    });
  });

  it('changes selected category when list emits selectCategory', async () => {
    expect(wrapper.findComponent(CategoryForm).props('category')).toStrictEqual(firstCategory);

    wrapper.findComponent(CategoryList).vm.$emit('selectCategory', secondCategory);
    await nextTick();

    expect(wrapper.findComponent(CategoryForm).props('category')).toStrictEqual(secondCategory);
  });

  it('renders the category details form', () => {
    expect(wrapper.findComponent(CategoryForm).props()).toStrictEqual({
      securityLabels: mockSecurityLabels,
      category: firstCategory,
    });
  });

  it('opens the drawer when form emits addLabel', async () => {
    wrapper.vm.$refs.labelDrawer.open = jest.fn();

    wrapper.findComponent(CategoryForm).vm.$emit('addLabel');
    await nextTick();

    expect(wrapper.vm.$refs.labelDrawer.open).toHaveBeenCalledWith('add', undefined);
  });

  it('opens the drawer when form emits editLabel', async () => {
    wrapper.vm.$refs.labelDrawer.open = jest.fn();

    wrapper.findComponent(CategoryForm).vm.$emit('editLabel', mockSecurityLabels[0]);
    await nextTick();

    expect(wrapper.vm.$refs.labelDrawer.open).toHaveBeenCalledWith(
      'edit',
      expect.objectContaining({ name: 'Asset Track' }),
    );
  });
});
