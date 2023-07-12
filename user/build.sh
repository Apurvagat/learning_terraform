#!/bin/bash

# Set CGO to 0 and build the Go executable
CGO_ENABLED=0 go build -o main

# Create the ZIP file with the Go executable
zip -q -r user.zip main
