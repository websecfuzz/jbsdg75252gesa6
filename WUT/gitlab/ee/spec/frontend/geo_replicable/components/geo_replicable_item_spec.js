import Vue, { nextTick } from 'vue';
// eslint-disable-next-line no-restricted-imports
import Vuex from 'vuex';
import { GlSprintf } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { capitalizeFirstCharacter } from '~/lib/utils/text_utility';
import { REPLICATION_STATUS_STATES, VERIFICATION_STATUS_STATES } from 'ee/geo_shared/constants';
import GeoReplicableItem from 'ee/geo_replicable/components/geo_replicable_item.vue';
import GeoListItem from 'ee/geo_shared/list/components/geo_list_item.vue';
import { ACTION_TYPES } from 'ee/geo_replicable/constants';
import { getStoreConfig } from 'ee/geo_replicable/store';
import {
  MOCK_BASIC_GRAPHQL_DATA,
  MOCK_REPLICABLE_TYPE,
  MOCK_REPLICABLE_BASE_PATH,
  MOCK_GRAPHQL_REGISTRY_CLASS,
} from '../mock_data';

Vue.use(Vuex);

describe('GeoReplicableItem', () => {
  let wrapper;
  const mockReplicable = MOCK_BASIC_GRAPHQL_DATA[0];
  const MOCK_NAME = `${MOCK_GRAPHQL_REGISTRY_CLASS}/${getIdFromGraphQLId(mockReplicable.id)}`;
  const MOCK_DETAILS_PATH = `${MOCK_REPLICABLE_BASE_PATH}/${getIdFromGraphQLId(mockReplicable.id)}`;

  const actionSpies = {
    initiateReplicableAction: jest.fn(),
  };

  const defaultProps = {
    registryId: mockReplicable.id,
    modelRecordId: 11,
    syncStatus: mockReplicable.state,
    verificationState: mockReplicable.verificationState,
    lastSynced: mockReplicable.lastSyncedAt,
    lastVerified: mockReplicable.verifiedAt,
    lastSyncFailure: mockReplicable.lastSyncFailure,
    verificationFailure: mockReplicable.verificationFailure,
  };

  const createComponent = ({ props, state, featureFlags } = {}) => {
    const store = new Vuex.Store({
      ...getStoreConfig({
        replicableType: MOCK_REPLICABLE_TYPE,
        ...state,
      }),
      actions: actionSpies,
    });

    wrapper = shallowMountExtended(GeoReplicableItem, {
      store,
      propsData: {
        ...defaultProps,
        ...props,
      },
      provide: {
        replicableBasePath: MOCK_REPLICABLE_BASE_PATH,
        graphqlRegistryClass: MOCK_GRAPHQL_REGISTRY_CLASS,
        glFeatures: { ...featureFlags },
      },
    });
  };

  const findGeoListItem = () => wrapper.findComponent(GeoListItem);
  const findReplicableItemModelRecordId = () => wrapper.findComponent(GlSprintf);

  describe('replicable item details path', () => {
    describe('when geoReplicablesShowView is false', () => {
      beforeEach(() => {
        createComponent({ featureFlags: { geoReplicablesShowView: false } });
      });

      it('renders GeoListItem with the correct name but no detailsPath', () => {
        expect(findGeoListItem().props('name')).toBe(MOCK_NAME);
        expect(findGeoListItem().props('detailsPath')).toBeNull();
      });
    });

    describe('when geoReplicablesShowView is true', () => {
      beforeEach(() => {
        createComponent({ featureFlags: { geoReplicablesShowView: true } });
      });

      it('renders GeoListItem with the correct name and detailsPath', () => {
        expect(findGeoListItem().props('name')).toBe(MOCK_NAME);
        expect(findGeoListItem().props('detailsPath')).toBe(MOCK_DETAILS_PATH);
      });
    });
  });

  describe('replicable item status', () => {
    const EXPECTED_REPLICATION_STATUS = {
      tooltip: `Replication: ${REPLICATION_STATUS_STATES.PENDING.title}`,
      icon: REPLICATION_STATUS_STATES.PENDING.icon,
      variant: REPLICATION_STATUS_STATES.PENDING.variant,
    };

    const EXPECTED_VERIFICATION_STATUS = {
      tooltip: `Verification: ${VERIFICATION_STATUS_STATES.SUCCEEDED.title}`,
      icon: VERIFICATION_STATUS_STATES.SUCCEEDED.icon,
      variant: VERIFICATION_STATUS_STATES.SUCCEEDED.variant,
    };

    const EXPECTED_UNKNOWN_VERIFICATION_STATUS = {
      tooltip: `Verification: ${VERIFICATION_STATUS_STATES.UNKNOWN.title}`,
      icon: VERIFICATION_STATUS_STATES.UNKNOWN.icon,
      variant: VERIFICATION_STATUS_STATES.UNKNOWN.variant,
    };

    describe.each`
      verificationEnabled | verificationState                   | expectedStatusArray
      ${false}            | ${mockReplicable.verificationState} | ${[EXPECTED_REPLICATION_STATUS]}
      ${true}             | ${mockReplicable.verificationState} | ${[EXPECTED_REPLICATION_STATUS, EXPECTED_VERIFICATION_STATUS]}
      ${true}             | ${null}                             | ${[EXPECTED_REPLICATION_STATUS, EXPECTED_UNKNOWN_VERIFICATION_STATUS]}
      ${true}             | ${'invalid_state'}                  | ${[EXPECTED_REPLICATION_STATUS, EXPECTED_UNKNOWN_VERIFICATION_STATUS]}
    `(
      'when verificationEnabled is $verificationEnabled and verificationState is $verificationState',
      ({ verificationEnabled, verificationState, expectedStatusArray }) => {
        beforeEach(() => {
          createComponent({
            props: { verificationState },
            state: { verificationEnabled },
          });
        });

        it('renders GeoListItem with correct statusArray', () => {
          expect(findGeoListItem().props('statusArray')).toStrictEqual(expectedStatusArray);
        });
      },
    );
  });

  describe("replicable item's time ago data", () => {
    const BASE_TIME_AGO = [
      {
        label: capitalizeFirstCharacter(mockReplicable.state.toLowerCase()),
        dateString: mockReplicable.lastSyncedAt,
        defaultText: 'Unknown',
      },
      {
        label: 'Last time verified',
        dateString: mockReplicable.verifiedAt,
        defaultText: null,
      },
    ];

    describe('when verificationEnabled is false', () => {
      beforeEach(() => {
        createComponent({ state: { verificationEnabled: false } });
      });

      it('render GeoListItem with the correct timeAgoArray prop', () => {
        const expectedTimeAgo = [
          BASE_TIME_AGO[0],
          { ...BASE_TIME_AGO[1], defaultText: 'Not applicable.' },
        ];

        expect(findGeoListItem().props('timeAgoArray')).toStrictEqual(expectedTimeAgo);
      });
    });

    describe('when verificationEnabled is true', () => {
      beforeEach(() => {
        createComponent({ state: { verificationEnabled: true } });
      });

      it('render GeoListItem with the correct timeAgoArray prop', () => {
        const expectedTimeAgo = [BASE_TIME_AGO[0], { ...BASE_TIME_AGO[1], defaultText: 'Unknown' }];

        expect(findGeoListItem().props('timeAgoArray')).toStrictEqual(expectedTimeAgo);
      });
    });
  });

  describe('replicable item actions', () => {
    const RESYNC_ACTION = {
      id: 'geo-resync-item',
      value: ACTION_TYPES.RESYNC,
      text: 'Resync',
    };

    const REVERIFY_ACTION = {
      id: 'geo-reverify-item',
      value: ACTION_TYPES.REVERIFY,
      text: 'Reverify',
    };

    describe('when verificationEnabled is false', () => {
      beforeEach(() => {
        createComponent({ state: { verificationEnabled: false } });
      });

      it('render GeoListItem with the correct actionsArray prop', () => {
        expect(findGeoListItem().props('actionsArray')).toStrictEqual([RESYNC_ACTION]);
      });

      it('handles resync action when `actionClicked` is emitted', async () => {
        findGeoListItem().vm.$emit('actionClicked', RESYNC_ACTION);
        await nextTick();

        expect(actionSpies.initiateReplicableAction).toHaveBeenCalledWith(expect.any(Object), {
          registryId: defaultProps.registryId,
          name: MOCK_NAME,
          action: ACTION_TYPES.RESYNC,
        });
      });
    });

    describe('when verificationEnabled is true', () => {
      beforeEach(() => {
        createComponent({ state: { verificationEnabled: true } });
      });

      it('render GeoListItem with the correct actionsArray prop', () => {
        expect(findGeoListItem().props('actionsArray')).toStrictEqual([
          RESYNC_ACTION,
          REVERIFY_ACTION,
        ]);
      });

      it('handles reverify action when `actionClicked` is emitted', async () => {
        findGeoListItem().vm.$emit('actionClicked', REVERIFY_ACTION);
        await nextTick();

        expect(actionSpies.initiateReplicableAction).toHaveBeenCalledWith(expect.any(Object), {
          registryId: defaultProps.registryId,
          name: MOCK_NAME,
          action: ACTION_TYPES.REVERIFY,
        });
      });
    });
  });

  describe('extra details', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders the model record ID in the extra details section', () => {
      expect(findReplicableItemModelRecordId().attributes('message')).toBe(
        'Model record: %{modelRecordId}',
      );
    });
  });

  describe.each`
    lastSyncFailure         | verificationFailure    | expectedErrors
    ${null}                 | ${null}                | ${[]}
    ${'Connection timeout'} | ${null}                | ${[{ label: 'Replication failure', message: 'Connection timeout' }]}
    ${null}                 | ${'Checksum mismatch'} | ${[{ label: 'Verification failure', message: 'Checksum mismatch' }]}
    ${'Connection timeout'} | ${'Checksum mismatch'} | ${[{ label: 'Replication failure', message: 'Connection timeout' }, { label: 'Verification failure', message: 'Checksum mismatch' }]}
  `('error handling', ({ lastSyncFailure, verificationFailure, expectedErrors }) => {
    describe(`when lastSyncFailure is "${lastSyncFailure}" and verificationFailure is "${verificationFailure}"`, () => {
      beforeEach(() => {
        createComponent({
          props: {
            lastSyncFailure,
            verificationFailure,
          },
        });
      });

      it(`renders GeoListItem with correct errors array`, () => {
        expect(findGeoListItem().props('errorsArray')).toStrictEqual(expectedErrors);
      });
    });
  });
});
