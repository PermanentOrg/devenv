#!/usr/bin/env bash


git checkout main
git pull origin main
cd ../infrastructure/
git checkout main
git pull origin main
cd ../upload-service
git checkout main
git pull origin main
cd ../web-app
git checkout main
git pull origin main
cd ../back-end
git checkout main
git pull origin main 

