import test from "node:test";
import assert from "node:assert/strict";
import { extensionOf, lookup, contentTypeFor } from "./mime.mjs";

test("query strings and fragments are stripped", () => {
  assert.equal(extensionOf("/assets/app.js?v=123"), "js");
  assert.equal(extensionOf("/img/logo.png#section"), "png");
  assert.equal(lookup("/assets/styles.css?cache=no"), "text/css");
});

test("dotfiles have no extension", () => {
  assert.equal(extensionOf(".gitignore"), "");
  assert.equal(extensionOf("/home/user/.bashrc"), "");
  assert.equal(lookup("/home/user/.bashrc"), "application/octet-stream");
});

test("no dot means no extension", () => {
  assert.equal(extensionOf("Makefile"), "");
  assert.equal(extensionOf("/usr/bin/node"), "");
  assert.equal(lookup("Makefile"), "application/octet-stream");
});

test("trailing dot gives empty extension", () => {
  assert.equal(extensionOf("notes."), "");
  assert.equal(lookup("notes."), "application/octet-stream");
});

test("gz and tar.gz map to gzip", () => {
  assert.equal(lookup("backup.tar.gz"), "application/gzip");
  assert.equal(lookup("gz"), "application/gzip");
});

test("charset applies to every textual type", () => {
  assert.equal(contentTypeFor("notes.md"), "text/markdown; charset=utf-8");
  assert.equal(contentTypeFor("data.csv"), "text/csv; charset=utf-8");
  assert.equal(contentTypeFor("feed.xml"), "application/xml; charset=utf-8");
  assert.equal(contentTypeFor("icon.svg"), "image/svg+xml; charset=utf-8");
  assert.equal(contentTypeFor("readme.txt"), "text/plain; charset=utf-8");
});

test("binary types stay bare", () => {
  assert.equal(contentTypeFor("font.woff2"), "font/woff2");
  assert.equal(contentTypeFor("mod.wasm"), "application/wasm");
  assert.equal(contentTypeFor("bundle.zip"), "application/zip");
  assert.equal(contentTypeFor("unknown.bin"), "application/octet-stream");
});

test("backslash separators with query strip", () => {
  assert.equal(lookup("C:\\site\\Index.HTM?x=1"), "text/html");
});
