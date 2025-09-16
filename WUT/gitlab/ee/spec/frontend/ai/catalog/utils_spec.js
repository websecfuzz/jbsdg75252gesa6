import { formValidators } from '@gitlab/ui/dist/utils';
// eslint-disable-next-line no-restricted-imports
import { s__, sprintf } from '~/locale';
import { createFieldValidators } from 'ee/ai/catalog/utils';

// Mock the dependencies
jest.mock('@gitlab/ui/dist/utils', () => ({
  formValidators: {
    required: jest.fn(),
    factory: jest.fn(),
  },
}));

jest.mock('~/locale', () => ({
  s__: jest.fn(),
  sprintf: jest.fn(),
}));

describe('createFieldValidators', () => {
  const mockRequiredValidator = jest.fn();
  const mockFactoryValidator = jest.fn();

  beforeEach(() => {
    jest.clearAllMocks();
    formValidators.required.mockReturnValue(mockRequiredValidator);
    formValidators.factory.mockReturnValue(mockFactoryValidator);
    s__.mockReturnValue('Input cannot exceed %{value} characters. Please shorten your input.');
    sprintf.mockReturnValue('Input cannot exceed 100 characters. Please shorten your input.');
  });

  describe('when no parameters are provided', () => {
    it('returns an empty array', () => {
      const result = createFieldValidators();
      expect(result).toEqual([]);
    });

    it('returns an empty array when empty object is passed', () => {
      const result = createFieldValidators({});
      expect(result).toEqual([]);
    });

    it('does not call any form validators', () => {
      createFieldValidators();
      expect(formValidators.required).not.toHaveBeenCalled();
      expect(formValidators.factory).not.toHaveBeenCalled();
    });
  });

  describe('when only requiredLabel is provided', () => {
    it('returns only the required validator', () => {
      const result = createFieldValidators({ requiredLabel: 'Field is required' });

      expect(result).toEqual([mockRequiredValidator]);
      expect(formValidators.required).toHaveBeenCalledWith('Field is required');
      expect(formValidators.factory).not.toHaveBeenCalled();
    });
  });

  describe('when only maxLength is provided', () => {
    it('returns only the max length validator', () => {
      const result = createFieldValidators({ maxLength: 100 });

      expect(result).toEqual([mockFactoryValidator]);
      expect(formValidators.required).not.toHaveBeenCalled();
      expect(formValidators.factory).toHaveBeenCalled();
    });

    it('calls sprintf with correct parameters', () => {
      createFieldValidators({ maxLength: 50 });

      expect(s__).toHaveBeenCalledWith(
        'AICatalog|Input cannot exceed %{value} characters. Please shorten your input.',
      );
      expect(sprintf).toHaveBeenCalledWith(
        'Input cannot exceed %{value} characters. Please shorten your input.',
        { value: 50 },
      );
    });
  });

  describe('when both parameters are provided', () => {
    it('returns both validators', () => {
      const result = createFieldValidators({
        requiredLabel: 'Required field',
        maxLength: 200,
      });

      expect(result).toEqual([mockRequiredValidator, mockFactoryValidator]);
      expect(formValidators.required).toHaveBeenCalledWith('Required field');
      expect(formValidators.factory).toHaveBeenCalled();
    });
  });
});
