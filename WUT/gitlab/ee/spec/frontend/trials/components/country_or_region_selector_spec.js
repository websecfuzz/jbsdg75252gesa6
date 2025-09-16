import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { mountExtended, shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import CountryOrRegionSelector from 'ee/trials/components/country_or_region_selector.vue';
import {
  COUNTRIES,
  STATES,
  COUNTRY_WITH_STATES,
  STATE,
} from 'ee_jest/hand_raise_leads/components/mock_data';

Vue.use(VueApollo);

describe('CountryOrRegionSelector', () => {
  let wrapper;

  const createComponent = (props = {}, mountFn = shallowMountExtended) => {
    const mockResolvers = {
      Query: {
        countries() {
          return COUNTRIES;
        },
        states() {
          return STATES;
        },
      },
    };

    return mountFn(CountryOrRegionSelector, {
      apolloProvider: createMockApollo([], mockResolvers),
      propsData: {
        country: COUNTRY_WITH_STATES,
        state: STATE,
        ...props,
      },
    });
  };

  const findFormInput = (testId) => wrapper.findByTestId(testId);

  describe('rendering', () => {
    beforeEach(() => {
      wrapper = createComponent();
    });

    it.each`
      testid                | value
      ${'country-dropdown'} | ${'US'}
      ${'state-dropdown'}   | ${'CA'}
    `('has the default injected value for $testid', ({ testid, value }) => {
      expect(findFormInput(testid).attributes('value')).toBe(value);
    });

    describe('with trackActionForErrors', () => {
      beforeEach(() => {
        wrapper = createComponent({ trackActionForErrors: '_trackActionForErrors_' });
      });

      it('adds an error tracking class to the country and state selectors', () => {
        expect(findFormInput('country-dropdown').props('selectClass')).toContain('js-track-error');
        expect(findFormInput('state-dropdown').props('selectClass')).toContain('js-track-error');
      });
    });

    describe('with 5 default countries at the top', () => {
      beforeEach(() => {
        wrapper = createComponent({}, mountExtended);
      });

      it('renders the top 5 countries at the beginning of the dropdown', () => {
        const options = findFormInput('country-dropdown').props('options');

        expect(options[0].name).toBe('Select a country or region');
        expect(options[0].id).toBe('');

        expect(options[1].id).toBe('US');
        expect(options[1].name).toBe('United States of America');

        expect(options[2].id).toBe('GB');
        expect(options[2].name).toBe('United Kingdom');

        expect(options[3].id).toBe('CA');
        expect(options[3].name).toBe('Canada');

        expect(options[4].id).toBe('DE');
        expect(options[4].name).toBe('Germany');

        expect(options[5].id).toBe('FR');
        expect(options[5].name).toBe('France');

        expect(options[6].id).toBe('separator');
        expect(options[6].disabled).toBe(true);
      });

      it('does not repeat countries', () => {
        const countryDropdown = findFormInput('country-dropdown');
        const options = countryDropdown.props('options');
        const countryIds = options.map((option) => option.id);
        const uniqueIds = new Set(countryIds);

        expect(uniqueIds.size).toBe(countryIds.length);
      });
    });
  });

  describe.each`
    country | hidden   | required
    ${'US'} | ${false} | ${'true'}
    ${'CA'} | ${false} | ${'true'}
    ${'NL'} | ${true}  | ${undefined}
  `('Country & State handling', ({ country, hidden, required }) => {
    describe(`when provided country is set to ${country}`, () => {
      beforeEach(() => {
        wrapper = createComponent({ country });
      });

      it(`should${hidden ? ' not' : ''} render the state`, async () => {
        await nextTick();

        expect(findFormInput('state-form-group').classes('gl-hidden')).toBe(hidden);
        expect(findFormInput('state-dropdown').attributes('required')).toBe(required);
      });
    });
  });

  describe('selection change', () => {
    it('emits the change event properly when country is changed', async () => {
      wrapper = createComponent();

      await findFormInput('country-dropdown').vm.$emit('change', true);

      expect(wrapper.emitted('change')[0]).toStrictEqual([
        { country: 'US', state: 'CA', stateRequired: true },
      ]);
    });

    it('emits the change event properly when country is changed with no state required', async () => {
      wrapper = createComponent({ country: 'NL' });

      await findFormInput('country-dropdown').vm.$emit('change', true);

      expect(wrapper.emitted('change')[0]).toStrictEqual([
        { country: 'NL', state: '', stateRequired: false },
      ]);
    });

    it('emits the change event properly when country is changed with state required', async () => {
      wrapper = createComponent({ country: 'US', state: '' });

      await findFormInput('country-dropdown').vm.$emit('change', true);

      expect(wrapper.emitted('change')[0]).toStrictEqual([
        { country: 'US', state: '', stateRequired: true },
      ]);
    });

    it('emits the change event properly when state is not required but has value', async () => {
      wrapper = createComponent({ country: 'NL', state: 'CA' });

      await findFormInput('country-dropdown').vm.$emit('change', true);

      expect(wrapper.emitted('change')[0]).toStrictEqual([
        { country: 'NL', state: '', stateRequired: false },
      ]);
    });

    it('emits the change event properly when state is changed', async () => {
      wrapper = createComponent();

      await findFormInput('state-dropdown').vm.$emit('change', true);

      expect(wrapper.emitted('change')[0]).toStrictEqual([
        { country: 'US', state: 'CA', stateRequired: true },
      ]);
    });

    it('has the proper value field populated with name', () => {
      wrapper = createComponent();

      expect(findFormInput('state-dropdown').attributes('value-field')).toBe('id');
    });
  });
});
