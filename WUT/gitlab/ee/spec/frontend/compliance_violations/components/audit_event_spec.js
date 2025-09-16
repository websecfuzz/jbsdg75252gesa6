import { GlLink } from '@gitlab/ui';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import AuditEvent from 'ee/compliance_violations/components/audit_event.vue';
import CrudComponent from '~/vue_shared/components/crud_component.vue';
import { humanize } from '~/lib/utils/text_utility';

describe('AuditEvent', () => {
  let wrapper;

  const mockAuditEvent = {
    eventName: 'merge_request_merged',
    entityType: 'Project',
    author: {
      name: 'John Doe',
    },
    ipAddress: '192.168.1.1',
  };

  const createComponent = (props = {}) => {
    wrapper = mountExtended(AuditEvent, {
      propsData: {
        auditEvent: mockAuditEvent,
        ...props,
      },
    });
  };

  const findAuditEventSection = () => wrapper.findComponent(CrudComponent);
  const findGlLink = () => wrapper.findComponent(GlLink);

  beforeEach(() => {
    createComponent();
  });

  describe('audit event section', () => {
    it('renders audit event section', () => {
      expect(findAuditEventSection().exists()).toBe(true);
    });

    it('renders the correct title', () => {
      const titleElement = wrapper.findByTestId('crud-title');
      expect(titleElement.text()).toBe('Audit event captured');
    });

    it('renders GlLink with correct content', () => {
      const link = findGlLink();
      expect(link.exists()).toBe(true);
      expect(link.text()).toContain(mockAuditEvent.author.name);
      expect(link.text()).toContain(mockAuditEvent.entityType);
      expect(link.text()).toContain(humanize(mockAuditEvent.eventName));
    });

    it('renders IP address information', () => {
      expect(wrapper.text()).toContain('Registered event IP');
      expect(wrapper.text()).toContain(mockAuditEvent.ipAddress);
    });
  });

  describe('interactions', () => {
    it('calls openDrawer method when link is clicked', () => {
      const openDrawerSpy = jest.spyOn(AuditEvent.methods, 'openDrawer');
      createComponent();

      findGlLink().vm.$emit('click');

      expect(openDrawerSpy).toHaveBeenCalled();

      openDrawerSpy.mockRestore();
    });
  });
});
