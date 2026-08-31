"use strict";

const fs = require("node:fs");

function parseOsRelease(contents) {
  const values = {};

  for (const line of contents.split(/\r?\n/)) {
    const match = line.match(/^([A-Z0-9_]+)=(.*)$/);
    if (!match) {
      continue;
    }

    let value = match[2];
    if (
      value.length >= 2 &&
      ((value.startsWith('"') && value.endsWith('"')) ||
        (value.startsWith("'") && value.endsWith("'")))
    ) {
      value = value.slice(1, -1);
    }
    values[match[1]] = value.replace(/\\(["'\\$`])/g, "$1");
  }

  return values;
}

function currentPlatform() {
  let glibcVersion = null;
  if (process.report && typeof process.report.getReport === "function") {
    const report = process.report.getReport();
    glibcVersion = report.header && report.header.glibcVersionRuntime;
  }

  let osRelease = {};
  try {
    osRelease = parseOsRelease(fs.readFileSync("/etc/os-release", "utf8"));
  } catch {
    // Validation below reports the missing distribution metadata.
  }

  return {
    platform: process.platform,
    arch: process.arch,
    glibcVersion,
    osRelease,
  };
}

function validatePlatform(info) {
  if (info.platform !== "linux") {
    throw new Error(
      `unsupported platform ${info.platform}; oh-my-devpod requires Ubuntu 24.04 on Linux x64/glibc`,
    );
  }
  if (info.arch !== "x64") {
    throw new Error(
      `unsupported architecture ${info.arch}; oh-my-devpod requires Linux x64`,
    );
  }
  if (!info.glibcVersion) {
    throw new Error(
      "unsupported C library; oh-my-devpod requires glibc (musl is not supported)",
    );
  }

  const id = info.osRelease.ID || "unknown";
  const version = info.osRelease.VERSION_ID || "unknown";
  if (id !== "ubuntu" || version !== "24.04") {
    throw new Error(
      `unsupported Linux distribution ${id} ${version}; oh-my-devpod requires Ubuntu 24.04`,
    );
  }
}

module.exports = {
  currentPlatform,
  parseOsRelease,
  validatePlatform,
};
