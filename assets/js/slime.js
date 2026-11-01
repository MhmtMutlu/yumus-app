// The hero slime responds to touch: a press squashes it, a drag stretches it towards the finger, and on
// release it springs back with a jelly wobble. Only the whole slime is deformed (one 2D affine matrix from
// a damped spring), so the rendered layers stay exactly as drawn. No dependencies, no network.
(() => {
  "use strict";

  const slime = document.querySelector("[data-squish]");
  if (!slime) return;

  const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)");

  // Spring: stiffness k (1/s²) and damping c (1/s). Underdamped, so a release wobbles a few times.
  const STIFFNESS = 260;
  const DAMPING = 9;
  // Reduced motion: critically damped, no wobble.
  const CALM_DAMPING = 2 * Math.sqrt(STIFFNESS);
  // A press squashes this much (vertical) and widens a little less (horizontal).
  const PRESS_SQUASH = 0.05;
  // A drag of `REACH` pixels gives about the full stretch; never more than MAX_STRETCH.
  const REACH = 160;
  const MAX_STRETCH = 0.15;
  const FOLLOW = 0.3;            // the slime's centre follows the finger this much
  const MAX_SHIFT = 46;          // px
  const KEY_KICK = 3.2;          // keyboard poke: initial squash velocity
  const REST_EPSILON = 0.0004;

  // State: a symmetric strain [xx, xy, yy] and a shift [x, y], each with a velocity.
  const value = { xx: 0, xy: 0, yy: 0, x: 0, y: 0 };
  const speed = { xx: 0, xy: 0, yy: 0, x: 0, y: 0 };
  const target = { xx: 0, xy: 0, yy: 0, x: 0, y: 0 };
  let pointer = null;   // { id, startX, startY }
  let frame = 0;
  let last = 0;

  slime.setAttribute("tabindex", "0");
  slime.setAttribute("role", "button");
  const hint = slime.getAttribute("data-squish");
  if (hint) slime.setAttribute("aria-label", `${slime.getAttribute("aria-label") || ""}. ${hint}`.replace(/^\. /, ""));
  slime.classList.add("is-squishy");

  function setRest() {
    for (const key in target) target[key] = 0;
  }

  // Stretch along the drag direction, thinner across it (roughly area-preserving), and follow the finger.
  function setDrag(dx, dy) {
    const length = Math.hypot(dx, dy);
    const amount = MAX_STRETCH * Math.tanh(length / REACH);
    const ux = length > 0 ? dx / length : 0;
    const uy = length > 0 ? dy / length : 1;
    const along = amount;
    const across = 1 / (1 + amount) - 1;
    // The press squash gives way to the stretch as the drag grows.
    const press = PRESS_SQUASH * (1 - amount / MAX_STRETCH);
    // E = along·u uᵀ + across·(I − u uᵀ), plus the press squash.
    target.xx = across + (along - across) * ux * ux + press * 0.6;
    target.yy = across + (along - across) * uy * uy - press;
    target.xy = (along - across) * ux * uy;
    const shift = Math.min(MAX_SHIFT, length * FOLLOW);
    target.x = length > 0 ? ux * shift : 0;
    target.y = length > 0 ? uy * shift : 0;
  }

  function render() {
    const a = 1 + value.xx;
    const d = 1 + value.yy;
    const b = value.xy;
    slime.style.setProperty("transform", `matrix(${a.toFixed(4)}, ${b.toFixed(4)}, ${b.toFixed(4)}, ${d.toFixed(4)}, ${value.x.toFixed(2)}, ${value.y.toFixed(2)})`);
  }

  function step(now) {
    const dt = Math.min(0.033, last ? (now - last) / 1000 : 0.016);
    last = now;
    const damping = reduceMotion.matches ? CALM_DAMPING : DAMPING;
    let moving = false;
    for (const key in value) {
      // Semi-implicit Euler: stable for these stiffnesses at 30–120 Hz.
      speed[key] += (-STIFFNESS * (value[key] - target[key]) - damping * speed[key]) * dt;
      value[key] += speed[key] * dt;
      const scale = key === "x" || key === "y" ? 0.05 : 1;
      if (Math.abs(value[key] - target[key]) * scale > REST_EPSILON || Math.abs(speed[key]) * scale > REST_EPSILON * 10) {
        moving = true;
      }
    }
    render();
    if (moving || pointer) {
      frame = requestAnimationFrame(step);
    } else {
      frame = 0;
      last = 0;
      slime.style.removeProperty("transform");
      slime.classList.remove("is-pressed");
    }
  }

  function wake() {
    if (!frame) {
      last = 0;
      frame = requestAnimationFrame(step);
    }
  }

  slime.addEventListener("pointerdown", (event) => {
    if (event.button !== 0 || pointer) return;
    pointer = { id: event.pointerId, startX: event.clientX, startY: event.clientY };
    slime.setPointerCapture(event.pointerId);
    slime.classList.add("is-pressed");
    setDrag(0, 0);
    wake();
  });

  slime.addEventListener("pointermove", (event) => {
    if (!pointer || event.pointerId !== pointer.id) return;
    setDrag(event.clientX - pointer.startX, event.clientY - pointer.startY);
  });

  function release(event) {
    if (!pointer || event.pointerId !== pointer.id) return;
    pointer = null;
    setRest();
    wake();
  }

  slime.addEventListener("pointerup", release);
  slime.addEventListener("pointercancel", release);
  slime.addEventListener("lostpointercapture", release);

  // Keyboard: Enter or Space pokes it.
  slime.addEventListener("keydown", (event) => {
    if (event.key !== "Enter" && event.key !== " ") return;
    event.preventDefault();
    speed.yy -= KEY_KICK;
    speed.xx += KEY_KICK * 0.6;
    wake();
  });
})();
