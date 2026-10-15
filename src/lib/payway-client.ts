"use client";

const FORM_ID = "aba_merchant_request";
const IFRAME_NAME = "aba_webservice";
const SCRIPT_ATTR = "data-payway-plugin";

/**
 * PayWay's checkout plugin opens its hosted page as a bottom sheet on mobile
 * and a modal on desktop. If the plugin fails to load we fall back to a plain
 * form POST, which renders the same hosted page as a full navigation.
 */
export async function openPaywayCheckout(options: {
  jsUrl: string;
  purchaseUrl: string;
  fields: Record<string, string>;
}): Promise<void> {
  const { jsUrl, purchaseUrl, fields } = options;

  await loadScript(jsUrl).catch(() => undefined);

  if (!document.querySelector(`iframe[name="${IFRAME_NAME}"]`)) {
    const iframe = document.createElement("iframe");
    iframe.name = IFRAME_NAME;
    iframe.style.display = "none";
    document.body.appendChild(iframe);
  }

  const form = document.createElement("form");
  form.id = FORM_ID;
  form.method = "POST";
  form.action = purchaseUrl;
  form.target = IFRAME_NAME;
  form.style.display = "none";

  for (const [name, value] of Object.entries(fields)) {
    const input = document.createElement("input");
    input.type = "hidden";
    input.name = name;
    input.value = value;
    form.appendChild(input);
  }

  document.body.appendChild(form);

  const payway = (
    window as unknown as { AbaPayway?: { checkout?: () => void } }
  ).AbaPayway;

  if (typeof payway?.checkout === "function") {
    payway.checkout();
  } else {
    form.submit();
  }
}

function loadScript(src: string): Promise<void> {
  return new Promise((resolve, reject) => {
    const existing = document.querySelector<HTMLScriptElement>(
      `script[${SCRIPT_ATTR}]`
    );
    if (existing) {
      if (existing.dataset.loaded === "true") resolve();
      else existing.addEventListener("load", () => resolve(), { once: true });
      return;
    }

    const script = document.createElement("script");
    script.src = src;
    script.async = true;
    script.setAttribute(SCRIPT_ATTR, "");
    script.addEventListener(
      "load",
      () => {
        script.dataset.loaded = "true";
        resolve();
      },
      { once: true }
    );
    script.addEventListener("error", () => reject(new Error("payway_script_failed")), {
      once: true,
    });
    document.head.appendChild(script);
  });
}
