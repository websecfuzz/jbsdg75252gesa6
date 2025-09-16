# frozen_string_literal: true

return unless Gitlab.com?

Gitlab::AppliedMl::SuggestedReviewers.ensure_secret!
