import { removeIds } from 'ee/security_orchestration/components/policy_editor/scan_result/advanced_settings/utils';

describe('removeIds', () => {
  it.each`
    items                                                       | expected
    ${undefined}                                                | ${[]}
    ${[]}                                                       | ${[]}
    ${[{ name: 'name1', id: '1' }]}                             | ${[{ name: 'name1' }]}
    ${[{ name: 'name1', id: '1' }, { name: 'name2', id: '2' }]} | ${[{ name: 'name1' }, { name: 'name2' }]}
    ${[{ name: 'name1' }]}                                      | ${[{ name: 'name1' }]}
  `('remove ids from objects with ids', ({ items, expected }) => {
    expect(removeIds(items)).toEqual(expected);
  });
});
