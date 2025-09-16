import { GlCard } from '@gitlab/ui';
import StatisticsSeatsCard from 'ee/usage_quotas/seats/components/statistics_seats_card.vue';

export default {
  component: StatisticsSeatsCard,
  title: 'ee/usage_quotas/seats/statistics_seats_card',
};

const Template = (_, { argTypes }) => ({
  components: { StatisticsSeatsCard, GlCard },
  props: Object.keys(argTypes),
  provide: {
    explorePlansPath: 'example.com',
    namespaceId: '42',
  },
  template: `<gl-card class="gl-w-1/2">
      <statistics-seats-card v-bind="$props">
      </statistics-seats-card>
     </gl-card>`,
});
export const Default = Template.bind({});

Default.args = {
  seatsUsed: 160,
  seatsOwed: 10,
  purchaseButtonLink: 'purchase.com/test',
};
