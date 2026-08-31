"use strict";

const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");

function selectSource(value, persistedValue) {
  const source = value || persistedValue || "github";
  if (source !== "github" && source !== "gitee") {
    throw new Error(
      `invalid OHMYDEVPOD_SOURCE=${source}; expected github or gitee`,
    );
  }
  return source;
}

function sourceStatePath(env = process.env, homeDirectory = os.homedir()) {
  const configHome = env.XDG_CONFIG_HOME || path.join(homeDirectory, ".config");
  return path.join(configHome, "oh-my-devpod", "npm-source");
}

function readPersistedSource(destination) {
  try {
    return fs.readFileSync(destination, "utf8").trim();
  } catch (error) {
    if (error.code === "ENOENT") {
      return undefined;
    }
    throw error;
  }
}

function persistSource(destination, source) {
  fs.mkdirSync(path.dirname(destination), { recursive: true });
  const temporary = `${destination}.${process.pid}.tmp`;
  fs.writeFileSync(temporary, `${source}\n`, { mode: 0o644 });
  fs.renameSync(temporary, destination);
}

module.exports = {
  persistSource,
  readPersistedSource,
  selectSource,
  sourceStatePath,
};
