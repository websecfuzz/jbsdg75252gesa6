#!/bin/bash

if ! [[ -d storybook/node_modules ]]; then
  yarn storybook:install
fi

if [[ "$1" == "--skip-fixtures-update" ]]; then
  echo "Proceeding without installing fixtures."
else
  echo "Storybook needs fixture files to run. Generate or download them."
  echo "See: https://docs.gitlab.com/ee/development/testing_guide/frontend_testing.html#frontend-test-fixtures"
  read -rp "Download fixtures? (y/N) " response

  if [ "$response" = "y" ]; then
    ./scripts/frontend/download_fixtures.sh
  fi
fi

yarn tailwindcss:build
yarn --cwd ./storybook start
