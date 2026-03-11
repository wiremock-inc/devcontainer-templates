#!/bin/bash
set -e

# Verify Java is installed
java -version

# Verify Node.js is installed
node --version

# Verify Claude Code CLI is installed
which claude

# Verify Gradle wrapper is usable (if present)
if [ -f ./gradlew ]; then
    ./gradlew --version | head -3
fi

# Verify firewall script exists
test -f /usr/local/bin/init-firewall.sh

echo "All tests passed."
