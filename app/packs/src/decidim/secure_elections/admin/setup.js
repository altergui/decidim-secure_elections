/**
 * The point of no return, guarded in the browser as well as on the server.
 *
 * `SetupForm` already refuses a submission whose acknowledgement is unticked or
 * whose confirmation phrase does not match, and that check stays: this file is
 * a second lock, not the lock. What it adds is that the button for an
 * irreversible, unrecoverable action is not sitting there enabled while neither
 * confirmation has been given — an admin should never be able to *press* it by
 * accident and find out afterwards.
 *
 * With the pack unavailable the button stays enabled and the server refuses the
 * request, which is the behaviour this page has always had.
 */

const WRAPPER_ID = "js-vocdoni-setup";

/**
 * The same loose comparison `SetupForm#normalize` performs, so the browser and
 * the server never disagree about whether the phrase was typed. Deliberately
 * forgiving about case and spacing: the point is a deliberate act, not a typing
 * exercise.
 *
 * @param {string} value the raw value.
 * @returns {string} the normalized value.
 */
const normalize = (value) => String(value || "").trim().replace(/ +/gu, " ").toLowerCase();

const setupPublishGuard = () => {
  const wrapper = document.getElementById(WRAPPER_ID);

  if (!wrapper) {
    return;
  }

  const button = wrapper.querySelector("[data-vocdoni-publish]");
  const checkbox = wrapper.querySelector("[data-vocdoni-confirm-irreversible]");
  const phrase = wrapper.querySelector("[data-vocdoni-confirm-phrase]");

  // The server already decided the election is not publishable — leave its
  // disabled button, and its explanation, exactly as rendered.
  if (!button || button.disabled || !checkbox || !phrase) {
    return;
  }

  const expected = normalize(wrapper.dataset.expectedPhrase);
  const hint = wrapper.querySelector("[data-vocdoni-publish-hint]");

  const refresh = () => {
    const ready = checkbox.checked && normalize(phrase.value) === expected;

    button.disabled = !ready;
    button.setAttribute("aria-disabled", String(!ready));

    if (hint) {
      hint.hidden = ready;
    }
  };

  checkbox.addEventListener("change", refresh);
  phrase.addEventListener("input", refresh);
  phrase.addEventListener("change", refresh);

  refresh();
};

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", setupPublishGuard);
} else {
  setupPublishGuard();
}

export default setupPublishGuard;
