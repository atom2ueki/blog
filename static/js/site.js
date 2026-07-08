document.addEventListener("DOMContentLoaded", () => {
  const FEEDBACK_MS = 1600;

  // --- Toast ---
  const toast = document.createElement("div");
  toast.className = "toast";
  document.body.appendChild(toast);
  let toastTimer;
  const showToast = (msg) => {
    clearTimeout(toastTimer);
    toast.textContent = msg;
    toast.classList.add("show");
    toastTimer = setTimeout(() => toast.classList.remove("show"), FEEDBACK_MS);
  };

  // --- Shared copy helper ---
  const copyText = async (text, msg, el) => {
    try {
      await navigator.clipboard.writeText(text);
      showToast(msg);
      if (el) {
        el.classList.add("copied");
        setTimeout(() => el.classList.remove("copied"), FEEDBACK_MS);
      }
    } catch (_e) {
      showToast("Copy failed");
    }
  };

  // --- Copy page ---
  const copyPageBtn = document.querySelector("[data-copy-source]");
  if (copyPageBtn) {
    const sourceId = copyPageBtn.getAttribute("data-copy-source");
    copyPageBtn.addEventListener("click", () => {
      const el = document.getElementById(sourceId);
      if (!el) return;
      const text = el.textContent.replace(/^\n+|\n+\s*$/g, "");
      copyText(text, "Copied to clipboard", copyPageBtn);
    });
  }

  // --- View as Markdown popup ---
  // Open the markdown source in a new tab via a blob: URL. We build the full
  // HTML document (with the markdown already baked in) and navigate to it,
  // rather than opening an empty popup and mutating its document afterwards —
  // modern browsers (process/site isolation) leave that as a blank about:blank
  // tab because the synchronous write to a swapped-out popup is a no-op.
  const viewBtn = document.querySelector("[data-view-source]");
  if (viewBtn) {
    const sourceId = viewBtn.getAttribute("data-view-source");
    viewBtn.addEventListener("click", () => {
      const el = document.getElementById(sourceId);
      if (!el) return;
      const text = el.textContent.replace(/^\n+|\n+\s*$/g, "");
      const esc = (s) => s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
      const html =
        "<!doctype html><html><head><meta charset=utf-8><title>Markdown View</title>" +
        "<style>body{margin:0;padding:24px;background:#1a1a2e;color:#c8c8c8;font:16px/1.6 Menlo,Consolas,monospace;white-space:pre-wrap}pre{margin:0;white-space:pre-wrap;word-break:break-word}</style>" +
        "</head><body><pre>" + esc(text) + "</pre></body></html>";
      const blob = new Blob([html], { type: "text/html;charset=utf-8" });
      const url = URL.createObjectURL(blob);
      const popup = window.open(url, "_blank");
      // Free the blob URL after the new tab has had time to load it.
      setTimeout(() => URL.revokeObjectURL(url), 10000);
      if (!popup) { showToast("Popup blocked"); }
    });
  }

  // --- Copy URL button ---
  const copyUrlBtn = document.querySelector("[data-copy-url]");
  if (copyUrlBtn) {
    const url = copyUrlBtn.getAttribute("data-copy-url");
    copyUrlBtn.addEventListener("click", () => copyText(url, "Link copied", copyUrlBtn));
  }

  // --- Heading anchor links ---
  document.querySelectorAll(".content__body h2, .content__body h3, .content__body h4").forEach((h) => {
    if (!h.id) return;
    const link = document.createElement("a");
    link.className = "heading-anchor";
    link.href = "#" + h.id;
    link.setAttribute("aria-label", "Link to this section");
    h.insertBefore(link, h.firstChild);
    link.addEventListener("click", (e) => {
      e.preventDefault();
      history.pushState(null, "", link.href);
      h.scrollIntoView({ behavior: "smooth" });
    });
  });

  // --- Code block copy buttons ---
  document.querySelectorAll(".content__body pre code").forEach((code) => {
    const pre = code.parentElement;
    const wrapper = document.createElement("div");
    wrapper.className = "code-block-wrapper";
    pre.parentNode.insertBefore(wrapper, pre);
    wrapper.appendChild(pre);
    const btn = document.createElement("button");
    btn.className = "code-copy-btn";
    btn.textContent = "copy";
    btn.addEventListener("click", async () => {
      try {
        await navigator.clipboard.writeText(code.textContent);
        btn.textContent = "copied!";
        btn.classList.add("copied");
        setTimeout(() => { btn.textContent = "copy"; btn.classList.remove("copied"); }, FEEDBACK_MS);
      } catch (_e) {
        btn.textContent = "failed";
      }
    });
    wrapper.appendChild(btn);
  });

  // --- Scroll spy for TOC ---
  const toc = document.getElementById("toc-sidebar");
  if (!toc) return;

  const tocLinks = toc.querySelectorAll("a");
  if (!tocLinks.length) return;

  const headings = [];
  tocLinks.forEach((link) => {
    const id = decodeURIComponent(link.getAttribute("href").slice(1));
    const el = document.getElementById(id);
    if (el) headings.push({ el, link });
  });
  if (!headings.length) return;

  let activeLink = null;
  const setActive = (next) => {
    if (next === activeLink) return;
    if (activeLink) activeLink.classList.remove("active");
    if (next) next.classList.add("active");
    activeLink = next;
  };

  const onScroll = () => {
    let current = null;
    for (let i = headings.length - 1; i >= 0; i--) {
      if (headings[i].el.getBoundingClientRect().top <= 100) {
        current = headings[i].link;
        break;
      }
    }
    setActive(current);
  };

  let ticking = false;
  window.addEventListener("scroll", () => {
    if (!ticking) {
      requestAnimationFrame(() => { onScroll(); ticking = false; });
      ticking = true;
    }
  });
  onScroll();
});
