import { GlSprintf, GlLink } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import {
  DEFAULT_SCHEDULE,
  INJECT,
  SCHEDULE,
} from 'ee/security_orchestration/components/policy_editor/pipeline_execution/constants';
import RuleSection from 'ee/security_orchestration/components/policy_editor/pipeline_execution/rule/rule_section.vue';
import ScheduleForm from 'ee/security_orchestration/components/policy_editor/pipeline_execution/rule/schedule_form.vue';

describe('RuleSection', () => {
  let wrapper;

  const createComponent = ({ propsData = {}, provide = {}, isStubbed = true } = {}) => {
    const stubs = isStubbed ? { GlSprintf } : {};

    wrapper = shallowMountExtended(RuleSection, {
      propsData,
      provide,
      stubs,
    });
  };

  const findGlSprintf = () => wrapper.findComponent(GlSprintf);
  const findGlLink = () => wrapper.findComponent(GlLink);
  const findScheduleForm = () => wrapper.findComponent(ScheduleForm);

  describe('rendering', () => {
    describe('when feature flag is off', () => {
      it('renders inject/override message when schedule is not selected', () => {
        createComponent({ propsData: { strategy: INJECT } });
        expect(wrapper.findComponent(GlSprintf).exists()).toBe(true);
        expect(findScheduleForm().exists()).toBe(false);
      });
    });

    describe('when feature flag is on', () => {
      it('renders inject/override message when schedule is not selected', () => {
        createComponent({
          propsData: { strategy: INJECT },
          provide: { glFeatures: { scheduledPipelineExecutionPolicies: true } },
        });
        expect(wrapper.findComponent(GlSprintf).exists()).toBe(true);
        expect(findScheduleForm().exists()).toBe(false);
      });

      describe('schedule form', () => {
        it('renders schedule form when schedule is selected', () => {
          createComponent({
            propsData: { strategy: SCHEDULE },
            provide: { glFeatures: { scheduledPipelineExecutionPolicies: true } },
          });
          expect(wrapper.findComponent(GlSprintf).exists()).toBe(false);
          expect(findScheduleForm().exists()).toBe(true);
          expect(findScheduleForm().props('schedule')).toEqual(DEFAULT_SCHEDULE);
        });

        it('passes schedule prop to ScheduleForm component', () => {
          const customSchedule = { type: 'weekly', days: ['Monday'] };
          createComponent({
            propsData: { schedules: [customSchedule], strategy: SCHEDULE },
            provide: { glFeatures: { scheduledPipelineExecutionPolicies: true } },
          });

          expect(findScheduleForm().props(SCHEDULE)).toEqual(customSchedule);
        });

        it('listens for changed event from schedule form', async () => {
          createComponent({
            propsData: { strategy: SCHEDULE },
            provide: { glFeatures: { scheduledPipelineExecutionPolicies: true } },
          });

          const updatedSchedule = { type: 'monthly', days_of_month: '15' };
          await findScheduleForm().vm.$emit('changed', updatedSchedule);

          expect(wrapper.emitted('changed')).toHaveLength(1);
          expect(wrapper.emitted('changed')[0][0]).toEqual(updatedSchedule);
        });
      });
    });
  });

  describe('inject/override message', () => {
    it('renders text', () => {
      createComponent({ isStubbed: false });
      expect(findGlSprintf().attributes('message')).toBe(
        'Configure your conditions in the pipeline execution file. %{linkStart}What can pipeline execution do?%{linkEnd}',
      );
    });

    it('renders link', () => {
      createComponent();
      expect(findGlLink().exists()).toBe(true);
      expect(findGlLink().text()).toBe('What can pipeline execution do?');
      expect(findGlLink().attributes('href')).toBe(
        '/help/user/application_security/policies/pipeline_execution_policies',
      );
    });
  });
});
