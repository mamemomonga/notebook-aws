#!/bin/bash 
# 参照
# https://github.com/mamemomonga/aws-boto3-helper
set -eu
exec docker run --rm -v $HOME/.aws:/home/app/.aws:ro \
	-e AWS_DEFAULT_PROFILE=$AWS_DEFAULT_PROFILE \
	mamemomonga/aws-boto3-helper $@

