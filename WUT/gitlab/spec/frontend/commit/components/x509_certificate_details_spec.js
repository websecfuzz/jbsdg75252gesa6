import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import X509CertificateDetails from '~/commit/components/x509_certificate_details.vue';
import { X509_CERTIFICATE_KEY_IDENTIFIER_TITLE } from '~/commit/constants';
import { x509CertificateDetailsProp } from '../mock_data';

describe('X509 certificate details', () => {
  let wrapper;

  const createComponent = () => {
    wrapper = shallowMountExtended(X509CertificateDetails, {
      propsData: x509CertificateDetailsProp,
    });
  };

  beforeEach(() => {
    createComponent();
  });

  const findTitle = () => wrapper.find('strong');
  const findSubjectValues = () => wrapper.findAllByTestId('subject-value');
  const findKeyIdentifier = () => wrapper.findByTestId('key-identifier');

  it('renders a title', () => {
    expect(findTitle().text()).toBe(x509CertificateDetailsProp.title);
  });

  it('renders subject values', () => {
    expect(findSubjectValues()).toHaveLength(3);
  });

  it('renders key identifier', () => {
    expect(findKeyIdentifier().text()).toBe(
      `${X509_CERTIFICATE_KEY_IDENTIFIER_TITLE} ${x509CertificateDetailsProp.subjectKeyIdentifier}`,
    );
  });
});
