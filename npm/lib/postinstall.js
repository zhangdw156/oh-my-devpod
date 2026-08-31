#!/usr/bin/env node
"use strict";

const path = require("node:path");
const { currentPlatform, validatePlatform } = require("./platform");
const {
  persistSource,
  readPersistedSource,
  selectSource,
  sourceStatePath,
} = require("./source");

function main(options = {}) {
  const env = options.env || process.env;
  const packageRoot = options.packageRoot || path.resolve(__dirname, "..");
  const platformInfo = options.platformInfo || currentPlatform();
  const stateFile =
    options.stateFile || sourceStatePath(env, options.homeDirectory);

  validatePlatform(platformInfo);
  const source = selectSource(
    env.OHMYDEVPOD_SOURCE,
    readPersistedSource(stateFile),
  );
  persistSource(stateFile, source);
  persistSource(path.join(packageRoot, ".npm-source"), source);
  return source;
}

if (require.main === module) {
  try {
    const source = main();
    process.stdout.write(`oh-my-devpod: configured npm source ${source}\n`);
  } catch (error) {
    process.stderr.write(`oh-my-devpod: ${error.message}\n`);
    process.exitCode = 1;
  }
}

module.exports = { main };
