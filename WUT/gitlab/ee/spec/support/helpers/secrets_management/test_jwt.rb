# frozen_string_literal: true

module SecretsManagement
  class TestJwt < SecretsManagerJwt
    # Override to provide static test claims
    # Override to skip project claims entirely
    def project_claims
      {
        user_id: '0',
        user_login: 'test-system',
        namespace_id: '0'
      }
    end
  end
end
