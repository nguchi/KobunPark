"use strict";

window.renderLatexPreview = function renderLatexPreview(source, displayMode) {
  const preview = document.getElementById("preview");
  preview.replaceChildren();

  try {
    window.katex.render(source, preview, {
      displayMode: Boolean(displayMode),
      output: "htmlAndMathml",
      strict: "ignore",
      throwOnError: true,
      trust: false,
      maxExpand: 1000,
      maxSize: 20
    });
    return { success: true };
  } catch (error) {
    preview.replaceChildren();
    return {
      success: false,
      message: String(error && error.message ? error.message : error)
    };
  }
};

window.clearLatexPreview = function clearLatexPreview() {
  document.getElementById("preview").replaceChildren();
};
