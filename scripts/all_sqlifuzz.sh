#!/bin/bash

./sqlifuzz.sh appwrite 8080 /console/login openapi.json schemathesis
./sqlifuzz.sh gitlab 8080 /users/sign_in openapi.yaml schemathesis
./sqlifuzz.sh wordpress3 8081 / api.json evomaster
./sqlifuzz.sh wordpress3 8081 / api.json schemathesis http://localhost:8888/wp-json
./sqlifuzz.sh casdoor 8081 /login openapi.json evomaster
./sqlifuzz.sh nodebb 4567 / read-bundled.yaml evomaster
./sqlifuzz.sh gitea 8081 /user/login openapi.yaml schemathesis
./sqlifuzz.sh bagisto 8081 / shop.json schemathesis
./sqlifuzz.sh prestashop 8081 / openapi.json schemathesis http://IBT2NAVAW4B1RZ2LGZVXMDSVSREUPJIJ@localhost:8888/api
./sqlifuzz.sh nextcloud 8081 / openapi.json schemathesis
./sqlifuzz.sh redmine 8081 / openapi.json schemathesis

./sqlifuzz.sh dvwa 8081 / openapi.json bacfuzz
./sqlifuzz.sh bwapp 8081 / openapi.json bacfuzz
./sqlifuzz.sh xvwa 8081 /xvwa openapi.json bacfuzz http://localhost:8888/xvwa
./sqlifuzz.sh wordpress3 8081 / api.json bacfuzz