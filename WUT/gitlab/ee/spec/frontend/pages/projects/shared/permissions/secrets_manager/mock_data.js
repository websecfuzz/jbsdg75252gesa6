export const secretManagerSettingsResponse = (status) => {
  return {
    data: {
      projectSecretsManager: {
        status,
        __typename: 'ProjectSecretsManager',
      },
    },
  };
};

export const initializeSecretManagerSettingsResponse = (errors = undefined) => {
  return {
    data: {
      projectSecretsManagerInitialize: {
        errors,
        projectSecretsManager: {
          status: 'PROVISIONING',
        },
        __typename: 'ProjectSecretsManagerInitializePayload',
      },
    },
  };
};
