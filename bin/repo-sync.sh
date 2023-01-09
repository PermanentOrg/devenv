#!/usr/bin/env bash

function checkout_and_update_main {
    git checkout main
    git pull origin main
}

checkout_and_update_main
cd ../infrastructure/
checkout_and_update_main
cd ../upload-service
checkout_and_update_main
cd ../web-app
checkout_and_update_main
cd ../back-end
checkout_and_update_main
cd ../stela
checkout_and_update_main
