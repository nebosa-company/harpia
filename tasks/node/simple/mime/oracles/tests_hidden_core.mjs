import test from "node:test";
import assert from "node:assert/strict";
import { extensionOf, lookup, contentTypeFor } from "./mime.mjs";

test("extensionOf takes the last dot of the basename", () => {
  assert.equal(extensionOf("index.html"), "html");
  assert.equal(extensionOf("archive.tar.gz"), "gz");
  assert.equal(extensionOf("/var/www/site/app.js"), "js");
  assert.equal(extensionOf("C:\\exports\\report.PDF"), "pdf");
});

test("lookup on bare extensions", () => {
  assert.equal(lookup("png"), "image/png");
  assert.equal(lookup(".png"), "image/png");
  assert.equal(lookup("PNG"), "image/png");
  assert.equal(lookup("woff2"), "font/woff2");
});

test("lookup on paths", () => {
  assert.equal(lookup("logo.svg"), "image/svg+xml");
  assert.equal(lookup("/a/b/video.mp4"), "video/mp4");
  assert.equal(lookup("song.MP3"), "audio/mpeg");
  assert.equal(lookup("mod.mjs"), "text/javascript");
});

test("unknown extensions fall back to octet-stream", () => {
  assert.equal(lookup("file.xyz"), "application/octet-stream");
  assert.equal(lookup("exe"), "application/octet-stream");
});

test("contentTypeFor adds charset for textual types", () => {
  assert.equal(contentTypeFor("index.html"), "text/html; charset=utf-8");
  assert.equal(contentTypeFor("app.js"), "text/javascript; charset=utf-8");
  assert.equal(contentTypeFor("data.json"), "application/json; charset=utf-8");
  assert.equal(contentTypeFor("logo.png"), "image/png");
  assert.equal(contentTypeFor("movie.mp4"), "video/mp4");
});
