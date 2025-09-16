import { convertRotationPeriod } from 'ee/ci/secrets/utils';

describe('Secrets Utils', () => {
  it.each`
    actualRotationPeriod | expectedRotationPeriod
    ${'14'}              | ${'Every 2 weeks'}
    ${'60'}              | ${'Every month'}
    ${'180'}             | ${'Every three months'}
    ${'0 6 * * *'}       | ${'0 6 * * *'}
  `(
    'converts $actualRotationPeriod to $expectedRotationPeriod',
    ({ actualRotationPeriod, expectedRotationPeriod }) => {
      expect(convertRotationPeriod(actualRotationPeriod)).toBe(expectedRotationPeriod);
    },
  );
});
