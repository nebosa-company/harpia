// Progressive enhancement only; the manual must work without JS.
document.addEventListener("DOMContentLoaded", () => {
  for (const heading of document.querySelectorAll("h1, h2")) {
    heading.title = "Section: " + heading.textContent;
  }
});
